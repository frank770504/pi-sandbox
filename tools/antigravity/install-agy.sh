#!/usr/bin/env bash
# Install the repo-managed Jev MCP server and workflow skill into Antigravity CLI.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
MCP_DIR="$REPO_DIR/tools/antigravity/jev-mcp"
SKILL_SOURCE="$REPO_DIR/tools/antigravity/skills/jev-development/SKILL.md"
RULE_SOURCE="$REPO_DIR/tools/antigravity/global-rule-addendum.md"
GLOBAL_GEMINI="$HOME/.gemini/GEMINI.md"
GLOBAL_SKILL="$HOME/.gemini/config/skills/jev-development/SKILL.md"
MCP_NAME="pi-sandbox-jev"
SERVER_ENTRY="$MCP_DIR/dist/index.js"

[ -f "$MCP_DIR/package-lock.json" ] || { echo "install-agy: package-lock.json missing; run npm install in $MCP_DIR" >&2; exit 1; }
[ -f "$SKILL_SOURCE" ] || { echo "install-agy: $SKILL_SOURCE not found" >&2; exit 1; }
[ -f "$RULE_SOURCE" ] || { echo "install-agy: $RULE_SOURCE not found" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "install-agy: node is required" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "install-agy: npm is required" >&2; exit 1; }
command -v agy >/dev/null 2>&1 || { echo "install-agy: agy CLI is required" >&2; exit 1; }
[ -f "$GLOBAL_GEMINI" ] || { echo "install-agy: expected existing global instructions at $GLOBAL_GEMINI" >&2; exit 1; }

# Validate the managed-rule merge before building or changing AGY configuration.
python3 - "$GLOBAL_GEMINI" "$RULE_SOURCE" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
rule = Path(sys.argv[2]).read_text(encoding='utf-8')
old = '3. **Wait:** Explicitly ask for my approval. Do NOT perform any file edits or command executions until I respond with "Go ahead" or "Approved."'
new = ('3. **Wait:** Explicitly ask for my approval before making changes or running tests/builds. '
       'Before approval, local read-only repository inspection and the narrowly scoped Jev planning evaluation below are allowed. '
       'Do NOT edit files, run tests/builds/installations, or run other mutating commands until I respond with "Go ahead" or "Approved."')
if old not in text and new not in text:
    raise SystemExit('install-agy: global approval sentence differs from the known template; refusing partial installation')
start = '<!-- BEGIN pi-sandbox Jev-assisted development workflow -->'
end = '<!-- END pi-sandbox Jev-assisted development workflow -->'
if (start in text) != (end in text):
    raise SystemExit('install-agy: incomplete managed rule markers in GEMINI.md; repair manually')
if not rule.strip().startswith(start) or not rule.strip().endswith(end):
    raise SystemExit('install-agy: workflow addendum markers are invalid')
PY

# Refuse to overwrite a separately maintained global skill.
if [ -e "$GLOBAL_SKILL" ] && ! cmp -s "$SKILL_SOURCE" "$GLOBAL_SKILL"; then
  echo "install-agy: $GLOBAL_SKILL already exists and differs; review/merge it manually." >&2
  exit 1
fi

# Build and test before modifying AGY's global configuration.
(cd "$MCP_DIR" && npm ci && npm run typecheck && npm test && npm run build)

mkdir -p "$(dirname "$GLOBAL_SKILL")"
if [ ! -e "$GLOBAL_SKILL" ]; then
  install -m 0644 "$SKILL_SOURCE" "$GLOBAL_SKILL"
  echo "install-agy: installed AGY skill -> $GLOBAL_SKILL"
else
  echo "install-agy: AGY skill already matches repo source"
fi

# Register only if no server with this name is already configured. Never place
# API-key values in the MCP command or AGY settings; the server inherits a
# secure environment supplied when AGY is launched.
if agy mcp list 2>&1 | grep -Fq "$MCP_NAME"; then
  echo "install-agy: MCP server '$MCP_NAME' already exists; leaving it unchanged"
else
  if [ -n "${TYPESAFE_API_KEY_FILE:-}" ]; then
    # Only the protected file path is persisted; the key value is never read here.
    agy mcp add --env "TYPESAFE_API_KEY_FILE=$TYPESAFE_API_KEY_FILE" "$MCP_NAME" node "$SERVER_ENTRY"
  else
    agy mcp add "$MCP_NAME" node "$SERVER_ENTRY"
  fi
  echo "install-agy: registered stdio MCP server '$MCP_NAME'"
fi

# Add/update only this managed rule block and the exact approval sentence this
# installation is designed to refine. Existing unrelated instructions remain.
python3 - "$GLOBAL_GEMINI" "$RULE_SOURCE" <<'PY'
from datetime import datetime
from pathlib import Path
import os
import shutil
import stat
import sys
import tempfile

file_path = Path(sys.argv[1])
rule_path = Path(sys.argv[2])
old_wait = '3. **Wait:** Explicitly ask for my approval. Do NOT perform any file edits or command executions until I respond with "Go ahead" or "Approved."'
new_wait = ('3. **Wait:** Explicitly ask for my approval before making changes or running tests/builds. '
            'Before approval, local read-only repository inspection and the narrowly scoped Jev planning evaluation below are allowed. '
            'Do NOT edit files, run tests/builds/installations, or run other mutating commands until I respond with "Go ahead" or "Approved."')
start_marker = '<!-- BEGIN pi-sandbox Jev-assisted development workflow -->'
end_marker = '<!-- END pi-sandbox Jev-assisted development workflow -->'

if not file_path.exists():
    raise SystemExit(f'install-agy: expected existing global instructions at {file_path}; refusing to replace/create them automatically')
text = file_path.read_text(encoding='utf-8')
if old_wait in text:
    text = text.replace(old_wait, new_wait, 1)
elif new_wait not in text:
    raise SystemExit('install-agy: global approval sentence differs from the known template; merge the read-only/Jev exception manually')

addition = rule_path.read_text(encoding='utf-8').strip()
has_start = start_marker in text
has_end = end_marker in text
if has_start != has_end:
    raise SystemExit('install-agy: incomplete managed rule markers in GEMINI.md; repair manually')
if has_start:
    before, rest = text.split(start_marker, 1)
    _, after = rest.split(end_marker, 1)
    text = before.rstrip() + '\n\n' + addition + after
else:
    text = text.rstrip() + '\n\n' + addition + '\n'

current = file_path.read_text(encoding='utf-8')
if text == current:
    print('install-agy: global GEMINI.md already matches the managed workflow')
    raise SystemExit(0)

stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
backup = file_path.with_name(file_path.name + f'.bak.{stamp}')
shutil.copy2(file_path, backup)
mode = stat.S_IMODE(file_path.stat().st_mode)
fd, temp_name = tempfile.mkstemp(prefix=file_path.name + '.', suffix='.tmp', dir=file_path.parent)
try:
    with os.fdopen(fd, 'w', encoding='utf-8') as stream:
        stream.write(text)
    os.chmod(temp_name, mode)
    os.replace(temp_name, file_path)
except Exception:
    # Keep any failed temporary file for inspection rather than deleting it.
    raise
print(f'install-agy: updated {file_path} (backup: {backup})')
PY

echo "install-agy: done. Set TYPESAFE_API_KEY in AGY's launch environment (or set TYPESAFE_API_KEY_FILE to an owner-only secret file)."
echo "install-agy: verify with 'agy mcp list'; start a new AGY session to load the MCP server and skill."
