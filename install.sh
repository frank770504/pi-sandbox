#!/usr/bin/env bash
# install.sh — legacy pi-snap installer and full environment orchestrator.
#
# Legacy behavior (kept for compatibility):
#   ./install.sh
#
# Full setup:
#   ./install.sh --all [--dry-run|--check] [--no-external]
#                  [--migrate-existing] [--link-popular] [--build]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Preserve the original one-command pi-snap setup. The component installer
# uses the same managed alias and backup helpers as the full environment setup.
if [ "$#" -eq 0 ]; then
  exec bash "$REPO_DIR/tools/install/install-pi.sh" --snap-only
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
Usage:
  ./install.sh                         install pi-snap only (legacy behavior)
  ./install.sh --all [options]         install Pi, AGY, and skills configuration

Options for --all:
  --dry-run          show changes without writing
  --check            report drift without writing; fail if any component is out of date
  --no-external      skip cloning/linking pinned third-party skill repositories
  --migrate-existing move conflicting common-skill directories intact to
                     ~/.pi-sandbox-backups/skills before linking repo sources
  --link-popular     symlink the popular-models extension instead of copying
  --build            rebuild/typecheck/test the AGY Jev MCP adapter

Component installers remain available under tools/install/.
After installation, run tools/install/verify.sh.
EOF
  exit 0
fi

[ "$1" = "--all" ] || {
  echo "install: unknown option '$1' (use --help)" >&2
  exit 2
}
shift

DRY_RUN=0
CHECK=0
NO_EXTERNAL=0
MIGRATE_EXISTING=0
LINK_POPULAR=0
BUILD=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --no-external) NO_EXTERNAL=1 ;;
    --migrate-existing) MIGRATE_EXISTING=1 ;;
    --link-popular) LINK_POPULAR=1 ;;
    --build) BUILD=1 ;;
    *) echo "install: unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ "$DRY_RUN" = 1 ] && [ "$CHECK" = 1 ]; then
  echo "install: --dry-run and --check cannot be combined" >&2
  exit 2
fi

PI_ARGS=()
SKILL_ARGS=()
AGY_ARGS=()
if [ "$DRY_RUN" = 1 ]; then
  PI_ARGS+=(--dry-run); SKILL_ARGS+=(--dry-run); AGY_ARGS+=(--dry-run)
elif [ "$CHECK" = 1 ]; then
  PI_ARGS+=(--check); SKILL_ARGS+=(--check); AGY_ARGS+=(--check)
fi
[ "$NO_EXTERNAL" = 1 ] && SKILL_ARGS+=(--no-external)
[ "$MIGRATE_EXISTING" = 1 ] && SKILL_ARGS+=(--migrate-existing)
[ "$LINK_POPULAR" = 1 ] && PI_ARGS+=(--link-popular)
[ "$BUILD" = 1 ] && AGY_ARGS+=(--build)

printf '[install] Pi configuration\n'
bash "$REPO_DIR/tools/install/install-pi.sh" "${PI_ARGS[@]}"
printf '\n[install] Skills\n'
bash "$REPO_DIR/tools/install/install-skills.sh" "${SKILL_ARGS[@]}"
printf '\n[install] Antigravity configuration\n'
bash "$REPO_DIR/tools/install/install-agy.sh" "${AGY_ARGS[@]}"

printf '\n[install] all requested components completed\n'
if [ "$DRY_RUN" = 1 ] || [ "$CHECK" = 1 ]; then
  printf '[install] run tools/install/verify.sh for a complete environment report\n'
else
  printf '[install] run tools/install/verify.sh to verify the installed environment\n'
  printf '[install] start a new Pi and AGY session to load settings, skills, hooks, and MCP tools\n'
fi
