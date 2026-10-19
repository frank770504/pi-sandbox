#!/usr/bin/env bash
# test-e2e.sh — exercise the root installer in isolated HOME directories.
# Uses an AGY CLI shim; never contacts TypeSafe or creates real credentials.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
expect() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

if [ ! -f "$REPO_ROOT/tools/antigravity/jev-mcp/dist/index.js" ]; then
  echo "test-e2e: build the AGY adapter first (./install.sh --all or npm run build)" >&2
  exit 2
fi

FAKE_BIN="$TMP/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/agy" <<'FAKE_AGY'
#!/usr/bin/env bash
set -euo pipefail
HOME="${HOME:?}"
CONFIG="$HOME/.gemini/config/mcp_config.json"
if [ "${1:-}" = "--version" ]; then
  echo "1.4.0"
  exit 0
fi
if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "list" ]; then
  python3 - "$CONFIG" <<'PY'
import json, pathlib, sys
path=pathlib.Path(sys.argv[1])
print('NAME            TYPE   STATUS   COMMAND/URL')
if path.exists():
    data=json.loads(path.read_text())
    for name, config in (data.get('mcpServers') or {}).items():
        status='disabled' if config.get('disabled') else 'enabled'
        print(f'{name:<15} stdio  {status:<8} {config.get("command", "")}')
PY
  exit 0
fi
if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "add" ]; then
  shift 2
  env_pair=""
  if [ "${1:-}" = "--env" ]; then env_pair="$2"; shift 2; fi
  name="$1"; shift
  command="$1"; shift
  python3 - "$CONFIG" "$name" "$command" "$env_pair" "$@" <<'PY'
import json, pathlib, sys
path=pathlib.Path(sys.argv[1]); name=sys.argv[2]; command=sys.argv[3]
env_pair=sys.argv[4]; args=sys.argv[5:]
try: data=json.loads(path.read_text())
except FileNotFoundError: data={}
servers=data.setdefault('mcpServers', {})
entry={'command':command, 'args':args, 'disabled':False}
if env_pair:
    key, value=env_pair.split('=',1)
    entry['env']={key:value}
servers[name]=entry
path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(json.dumps(data,indent=2)+'\n')
PY
  exit 0
fi
echo "fake agy: unsupported command" >&2
exit 2
FAKE_AGY
chmod +x "$FAKE_BIN/agy"
cat > "$FAKE_BIN/pi" <<'FAKE_PI'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--version" ]; then
  echo "1.3.0"
  exit 0
fi
if [ "${1:-}" = "install" ] && [ "${2:-}" = "npm:pi-jev" ]; then
  dir="$HOME/.pi/agent/npm/node_modules/pi-jev"
  mkdir -p "$dir"
  printf '%s\n' '{"name":"pi-jev","version":"test-fixture"}' > "$dir/package.json"
  echo "fake pi installed npm:pi-jev"
  exit 0
fi
if [ "${1:-}" = "list" ]; then
  echo "User packages: npm:pi-jev"
  exit 0
fi
echo "fake pi: unsupported command" >&2
exit 2
FAKE_PI
chmod +x "$FAKE_BIN/pi"

make_seed_home() {
  local home="$1"
  mkdir -p "$home/.pi/agent" "$home/.gemini/antigravity-cli" "$home/.gemini/config"
  printf '%s\n' '{"lastChangelogVersion":"fixture-version","packages":["npm:fixture-package"],"fixturePi":{"retain":true}}' > "$home/.pi/agent/settings.json"
  printf '%s\n' '{"model":{"name":"fixture-model"},"trustedWorkspaces":["fixture-workspace"],"permissions":{"allow":["command(*)"],"deny":["command(sudo *)"]},"fixtureAgy":"keep"}' > "$home/.gemini/antigravity-cli/settings.json"
  printf '%s\n' '{"fixture.key":["f12"]}' > "$home/.gemini/antigravity-cli/keybindings.json"
  printf '%s\n' '{"fixtureConfig":true,"plugins":{"fixture-plugin":{"enabled":false}}}' > "$home/.gemini/config/config.json"
  printf '%s\n' '{"entries":[{"path":"fixture-skills"}]}' > "$home/.gemini/config/plugins.json"
  printf '%s\n' 'export FIXTURE_KEEP=1' > "$home/.bashrc"
}

backup_count() {
  find "$1" -type f -name '*.bak.*' -print 2>/dev/null | wc -l | tr -d ' '
}

snapshot_home() {
  python3 - "$1" <<'PY'
import hashlib, os, pathlib, sys
root=pathlib.Path(sys.argv[1])
rows=[]
for path in sorted(root.rglob('*')):
    rel=str(path.relative_to(root))
    if path.is_symlink():
        rows.append((rel,'link',os.readlink(path)))
    elif path.is_file():
        rows.append((rel,'file',hashlib.sha256(path.read_bytes()).hexdigest()))
print(hashlib.sha256(repr(rows).encode()).hexdigest())
PY
}

HOME_TEST="$TMP/full-home"
mkdir -p "$HOME_TEST"
make_seed_home "$HOME_TEST"
export HOME="$HOME_TEST"
export PATH="$FAKE_BIN:$PATH"

printf '== full install in temporary HOME ==\n'
bash "$REPO_ROOT/install.sh" --all --no-external
expect 'Pi unrelated settings preserved' python3 - "$HOME_TEST/.pi/agent/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); assert d['lastChangelogVersion']=='fixture-version'; assert d['fixturePi']['retain'] is True; assert 'npm:fixture-package' in d['packages'] and 'npm:pi-jev' in d['packages']
PY
expect 'Pi Jev package installed by command shim' test -f "$HOME_TEST/.pi/agent/npm/node_modules/pi-jev/package.json"
expect 'AGY unrelated settings and deny preserved' python3 - "$HOME_TEST/.gemini/antigravity-cli/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); assert d['model']['name']=='fixture-model'; assert d['trustedWorkspaces']==['fixture-workspace']; assert 'command(sudo *)' in d['permissions']['deny']; assert d['fixtureAgy']=='keep'; assert 'mcp(pi-sandbox-jev/jev_evaluate)' in d['permissions']['allow']
PY
expect 'AGY unrelated keybinding preserved' python3 - "$HOME_TEST/.gemini/antigravity-cli/keybindings.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['fixture.key']==['f12']
PY
expect 'no auth, trust, or TypeSafe secret generated' python3 - "$HOME_TEST" <<'PY'
import pathlib,sys
h=pathlib.Path(sys.argv[1])
assert not (h/'.pi/agent/auth.json').exists()
assert not (h/'.pi/agent/trust.json').exists()
assert not (h/'.config/typesafe/jev_api_key').exists()
assert not (h/'.pi/agent/secrets/typesafe_api_key').exists()
PY
expect 'common skill links installed' test -L "$HOME_TEST/.pi/agent/skills/catch-up-project"
expect 'AGY MCP server registered by shim' python3 - "$HOME_TEST/.gemini/config/mcp_config.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); s=d['mcpServers']['pi-sandbox-jev']; assert s['command']=='node' and not s.get('disabled',False)
PY
expect 'separate shell-profile changes retain distinct backups' python3 - "$HOME_TEST" <<'PY'
import glob, pathlib, sys
home=pathlib.Path(sys.argv[1]); backups=sorted(glob.glob(str(home/'.bashrc.bak.*')))
assert len(backups)==2, backups
first=pathlib.Path(backups[0]).read_text(); second=pathlib.Path(backups[1]).read_text()
assert 'export FIXTURE_KEEP=1' in first and 'pi-sandbox jev-auto' not in first
assert 'export FIXTURE_KEEP=1' in second and 'pi-sandbox jev-auto' in second
PY
if env HOME="$HOME_TEST" PATH="$FAKE_BIN:$PATH" bash "$REPO_ROOT/tools/install/verify.sh" --no-external >/dev/null; then
  pass 'verifier accepts temporary setup without credentials'
else
  fail 'verifier accepts temporary setup without credentials'
fi
if env HOME="$HOME_TEST" PATH="$FAKE_BIN:$PATH" bash "$REPO_ROOT/tools/install/verify.sh" --no-external --strict-credentials >/dev/null 2>&1; then
  fail 'strict verifier rejects missing credentials'
else
  pass 'strict verifier rejects missing credentials'
fi

before_backups="$(backup_count "$HOME_TEST")"
printf '\n== repeat install ==\n'
bash "$REPO_ROOT/install.sh" --all --no-external >/dev/null
expect 'second install creates no new backups' [ "$(backup_count "$HOME_TEST")" = "$before_backups" ]

printf '\n== dry-run and check ==\n'
before="$(snapshot_home "$HOME_TEST")"
bash "$REPO_ROOT/install.sh" --all --no-external --dry-run >/dev/null
expect 'dry-run leaves HOME unchanged' [ "$(snapshot_home "$HOME_TEST")" = "$before" ]
bash "$REPO_ROOT/install.sh" --all --no-external --check >/dev/null
expect 'check mode accepts installed state' [ "$?" -eq 0 ]

printf '\n== legacy installer ==\n'
LEGACY_HOME="$TMP/legacy-home"
mkdir -p "$LEGACY_HOME"
HOME="$LEGACY_HOME" PATH="$FAKE_BIN:$PATH" bash "$REPO_ROOT/install.sh" >/dev/null
expect 'bare ./install.sh installs pi-snap' test -x "$LEGACY_HOME/.pi/agent/bin/pi-snap"
expect 'bare ./install.sh does not install full Pi config' [ ! -f "$LEGACY_HOME/.pi/agent/settings.json" ]

printf '\n== preserve a conflicting AGY plugin directory ==\n'
CONFLICT_HOME="$TMP/conflict-home"
mkdir -p "$CONFLICT_HOME/.gemini/config/plugins/pi-sandbox-jev"
printf 'user-owned\n' > "$CONFLICT_HOME/.gemini/config/plugins/pi-sandbox-jev/user-file"
if HOME="$CONFLICT_HOME" PATH="$FAKE_BIN:$PATH" bash "$REPO_ROOT/install.sh" --all --no-external >/dev/null 2>&1; then
  fail 'conflicting AGY plugin directory is refused'
else
  pass 'conflicting AGY plugin directory is refused'
fi
expect 'conflicting plugin content remains intact' grep -q 'user-owned' "$CONFLICT_HOME/.gemini/config/plugins/pi-sandbox-jev/user-file"

printf '\npassed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
