#!/usr/bin/env bash
# test-skills.sh — safe-path and explicit migration tests for install-skills.sh.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$DIR/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
expect() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

linked_to() {
  [ -L "$1" ] && [ "$(readlink -f "$1" 2>/dev/null)" = "$(readlink -f "$2" 2>/dev/null)" ]
}

echo '== clean home install =='
CLEAN="$TMP/clean"
mkdir -p "$CLEAN"
HOME="$CLEAN" bash "$DIR/install-skills.sh" --no-external >/dev/null 2>&1
expect 'clean Pi catch-up link' linked_to "$CLEAN/.pi/agent/skills/catch-up-project" "$REPO_ROOT/skills/common/catch-up-project"
expect 'clean Pi grill-me link' linked_to "$CLEAN/.pi/agent/skills/grill-me" "$REPO_ROOT/skills/common/grill-me"
expect 'clean AGY catch-up link' linked_to "$CLEAN/.gemini/config/skills/catch-up-project" "$REPO_ROOT/skills/common/catch-up-project"
expect 'clean AGY grill-me link' linked_to "$CLEAN/.gemini/config/skills/grill-me" "$REPO_ROOT/skills/common/grill-me"

HOME="$CLEAN" bash "$DIR/install-skills.sh" --no-external >/dev/null 2>&1
expect 'second run unchanged' [ "$?" -eq 0 ]
HOME="$CLEAN" bash "$DIR/install-skills.sh" --no-external --check >/dev/null 2>&1
expect 'check mode clean' [ "$?" -eq 0 ]

echo '== preserve without migration permission =='
CONFLICT="$TMP/conflict"
mkdir -p "$CONFLICT/.pi/agent/skills/catch-up-project"
printf 'user content\n' > "$CONFLICT/.pi/agent/skills/catch-up-project/SKILL.md"
HOME="$CONFLICT" bash "$DIR/install-skills.sh" --no-external >/dev/null 2>&1
rc=$?
expect 'conflicting directory returns blocked status' [ "$rc" -eq 2 ]
expect 'conflicting directory remains intact' grep -q 'user content' "$CONFLICT/.pi/agent/skills/catch-up-project/SKILL.md"
expect 'no backup/move without explicit migration flag' [ ! -d "$CONFLICT/.pi-sandbox-backups/skills" ]

echo '== explicit migration preserves originals =='
MIGRATE="$TMP/migrate"
mkdir -p "$MIGRATE/.pi/agent/skills/catch-up-project" "$MIGRATE/.gemini/skills/catch-up-project"
printf 'old Pi copy\n' > "$MIGRATE/.pi/agent/skills/catch-up-project/SKILL.md"
printf 'old AGY copy\n' > "$MIGRATE/.gemini/skills/catch-up-project/SKILL.md"
HOME="$MIGRATE" bash "$DIR/install-skills.sh" --no-external --migrate-existing >/dev/null 2>&1
expect 'migration links Pi canonical source' linked_to "$MIGRATE/.pi/agent/skills/catch-up-project" "$REPO_ROOT/skills/common/catch-up-project"
expect 'migration links AGY canonical source' linked_to "$MIGRATE/.gemini/config/skills/catch-up-project" "$REPO_ROOT/skills/common/catch-up-project"
expect 'original Pi content preserved in backup' grep -R -q 'old Pi copy' "$MIGRATE/.pi-sandbox-backups/skills"
expect 'original AGY content preserved outside discovery dirs' grep -R -q 'old AGY copy' "$MIGRATE/.pi-sandbox-backups/skills"
expect 'backup directory not under skill discovery roots' [ ! -e "$MIGRATE/.gemini/skills/catch-up-project" ]

printf '\npassed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
