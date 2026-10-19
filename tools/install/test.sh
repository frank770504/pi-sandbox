#!/usr/bin/env bash
# test.sh — unit tests for the installer library and merge helpers.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

# expect_eq NAME EXPECTED ACTUAL
expect_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"
    printf '       expected: %s\n       actual:   %s\n' "$2" "$3"
  fi
}

# expect_rc NAME EXPECTED_RC ACTUAL_RC
expect_rc() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1 (expected rc $2, got $3)"
  fi
}

json() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d$1)" "$2"; }

echo "== merge-json.py =="

cat > "$TMP/t.json" <<'EOF'
{"defaultModel": "new-model", "packages": ["npm:pi-jev"], "statusLine": {"enabled": true}}
EOF
cat > "$TMP/target.json" <<'EOF'
{
  "lastChangelogVersion": "1.3.0",
  "defaultModel": "old-model",
  "extra": {"keep": 1},
  "statusLine": {"enabled": false, "custom": "keep"}
}
EOF

python3 "$DIR/merge-json.py" --check "$TMP/t.json" "$TMP/target.json" >/dev/null 2>&1
expect_rc "check detects difference" 3 $?

python3 "$DIR/merge-json.py" "$TMP/t.json" "$TMP/target.json" > "$TMP/merged.json"
expect_eq "managed key updated" "new-model" "$(json "['defaultModel']" "$TMP/merged.json")"
expect_eq "unrelated top key preserved" "1.3.0" "$(json "['lastChangelogVersion']" "$TMP/merged.json")"
expect_eq "unrelated nested key preserved" "1" "$(json "['extra']['keep']" "$TMP/merged.json")"
expect_eq "unrelated nested subkey preserved" "keep" "$(json "['statusLine']['custom']" "$TMP/merged.json")"
expect_eq "managed nested key updated" "True" "$(json "['statusLine']['enabled']" "$TMP/merged.json")"

python3 "$DIR/merge-json.py" --check "$TMP/t.json" "$TMP/merged.json" >/dev/null 2>&1
expect_rc "check identical" 0 $?

cat > "$TMP/additive-template.json" <<'EOF'
{"permissions": {"allow": ["mcp(pi-sandbox-jev)"]}, "entries": [{"path": "plugins"}], "packages": ["npm:pi-jev"]}
EOF
cat > "$TMP/additive-target.json" <<'EOF'
{"permissions": {"allow": ["command(*)", "mcp(existing)"]}, "entries": [{"path": "other"}], "packages": ["npm:existing"]}
EOF
python3 "$DIR/merge-json.py" --append-path permissions.allow --append-path entries --append-path packages \
  "$TMP/additive-template.json" "$TMP/additive-target.json" > "$TMP/additive-merged.json"
expect_eq "additive permission preserves existing rules" "3" "$(json "['permissions']['allow'].__len__()" "$TMP/additive-merged.json")"
expect_eq "additive permission appended" "mcp(pi-sandbox-jev)" "$(json "['permissions']['allow'][2]" "$TMP/additive-merged.json")"
expect_eq "additive entries preserve existing entry" "other" "$(json "['entries'][0]['path']" "$TMP/additive-merged.json")"
expect_eq "additive entries appended" "plugins" "$(json "['entries'][1]['path']" "$TMP/additive-merged.json")"
expect_eq "additive packages preserve existing package" "npm:existing" "$(json "['packages'][0]" "$TMP/additive-merged.json")"
expect_eq "additive packages appended" "npm:pi-jev" "$(json "['packages'][1]" "$TMP/additive-merged.json")"
python3 "$DIR/merge-json.py" --append-path permissions.allow --append-path entries --append-path packages \
  --check "$TMP/additive-template.json" "$TMP/additive-merged.json" >/dev/null 2>&1
expect_rc "additive merge idempotent" 0 $?

python3 "$DIR/merge-json.py" --check "$TMP/t.json" "$TMP/missing.json" >/dev/null 2>&1
expect_rc "check missing target" 3 $?

printf 'not json' > "$TMP/bad.json"
python3 "$DIR/merge-json.py" --check "$TMP/t.json" "$TMP/bad.json" >/dev/null 2>&1
expect_rc "invalid target fails closed" 1 $?
expect_eq "invalid target unchanged" "not json" "$(cat "$TMP/bad.json")"

echo "== merge-lines.py =="

cat > "$TMP/block.txt" <<'EOF'
PI_JEV_AUTO=1
EOF
B="# BEGIN test block"; E="# END test block"

printf 'export PATH=1\n' > "$TMP/rc"
python3 "$DIR/merge-lines.py" --file "$TMP/rc" --block-file "$TMP/block.txt" --begin "$B" --end "$E" > "$TMP/rc.new"
expect_eq "block inserted with markers" "2" "$(grep -cE 'BEGIN test block|END test block' "$TMP/rc.new")"
mv "$TMP/rc.new" "$TMP/rc"

printf 'PI_JEV_AUTO=0\n' > "$TMP/block.txt"
python3 "$DIR/merge-lines.py" --file "$TMP/rc" --block-file "$TMP/block.txt" --begin "$B" --end "$E" > "$TMP/rc.new"
expect_eq "block replaced" "1" "$(grep -c "PI_JEV_AUTO=0" "$TMP/rc.new")"
expect_eq "old block gone" "0" "$(grep -c "PI_JEV_AUTO=1" "$TMP/rc.new")"
expect_eq "surrounding text preserved" "export PATH=1" "$(head -1 "$TMP/rc.new")"
mv "$TMP/rc.new" "$TMP/rc"

python3 "$DIR/merge-lines.py" --check --file "$TMP/rc" --block-file "$TMP/block.txt" --begin "$B" --end "$E" >/dev/null 2>&1
expect_rc "block idempotent" 0 $?

printf '%s\n' "$B" > "$TMP/unbalanced"
python3 "$DIR/merge-lines.py" --file "$TMP/unbalanced" --block-file "$TMP/block.txt" --begin "$B" --end "$E" >/dev/null 2>&1
expect_rc "unbalanced markers fail closed" 1 $?

printf 'top\n\n%s\nmanaged\n%s\n\nbottom\n' "$B" "$E" > "$TMP/rem"
python3 "$DIR/merge-lines.py" --remove --file "$TMP/rem" --begin "$B" --end "$E" > "$TMP/rem.new"
expect_eq "remove drops markers" "0" "$(grep -c 'test block' "$TMP/rem.new")"
expect_eq "remove keeps top" "top" "$(head -1 "$TMP/rem.new")"
expect_eq "remove keeps bottom" "bottom" "$(tail -1 "$TMP/rem.new")"
mv "$TMP/rem.new" "$TMP/rem"
python3 "$DIR/merge-lines.py" --check --remove --file "$TMP/rem" --begin "$B" --end "$E" >/dev/null 2>&1
expect_rc "remove idempotent" 0 $?

printf 'plain\n' > "$TMP/plain"
python3 "$DIR/merge-lines.py" --check --remove --file "$TMP/plain" --begin "$B" --end "$E" >/dev/null 2>&1
expect_rc "remove no-op when absent" 0 $?

printf '%s\n' "$E" > "$TMP/endonly"
python3 "$DIR/merge-lines.py" --remove --file "$TMP/endonly" --begin "$B" --end "$E" >/dev/null 2>&1
expect_rc "remove unbalanced fails closed" 1 $?

echo "== lib.sh =="

# shellcheck source=/dev/null
. "$DIR/lib.sh"

cat > "$TMP/lib-template.json" <<'EOF'
{"defaultModel": "new-model", "theme": "dark"}
EOF
export DRY_RUN=1 CHECK=0 CHANGES=0
install_json_merge "$TMP/lib-template.json" "$TMP/lib-target.json" test >/dev/null 2>&1
expect_eq "dry-run does not create target" "missing" "$([ -e "$TMP/lib-target.json" ] && echo present || echo missing)"

export DRY_RUN=0 CHECK=0 CHANGES=0
install_json_merge "$TMP/lib-template.json" "$TMP/lib-target.json" test >/dev/null 2>&1
expect_eq "merge creates target" "dark" "$(json "['theme']" "$TMP/lib-target.json")"
expect_eq "first run reports change" "1" "$CHANGES"

cat > "$TMP/other-template.json" <<'EOF'
{"defaultModel": "changed"}
EOF
export DRY_RUN=0 CHECK=0 CHANGES=0
install_json_merge "$TMP/other-template.json" "$TMP/lib-target.json" test >/dev/null 2>&1
expect_eq "second differing run reports change" "1" "$CHANGES"
expect_eq "backup created" "1" "$(find "$TMP" -maxdepth 1 -name 'lib-target.json.bak.*' | wc -l | tr -d ' ')"

export DRY_RUN=0 CHECK=0 CHANGES=0
install_json_merge "$TMP/other-template.json" "$TMP/lib-target.json" test >/dev/null 2>&1
expect_eq "idempotent rerun reports no change" "0" "$CHANGES"

export DRY_RUN=0 CHECK=1 CHANGES=0
install_json_merge "$TMP/lib-template.json" "$TMP/lib-target.json" test >/dev/null 2>&1
expect_eq "check mode reports outdated" "1" "$CHANGES"

cat > "$TMP/backup-source" <<'EOF'
new content
EOF
printf 'old content\n' > "$TMP/backup-target"
if ( . "$DIR/lib.sh"; cp() { return 1; }; DRY_RUN=0 CHECK=0 CHANGES=0; install_copy "$TMP/backup-source" "$TMP/backup-target" 0644 "backup failure fixture" >/dev/null 2>&1 ); then
  fail "backup failure blocks overwrite"
else
  pass "backup failure blocks overwrite"
fi
expect_eq "backup failure leaves target unchanged" "old content" "$(cat "$TMP/backup-target")"

echo
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
