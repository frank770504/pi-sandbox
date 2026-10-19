#!/usr/bin/env bash
# install-pi.sh — install/merge the repo-managed Pi configuration.
#
# Usage:
#   install-pi.sh [--dry-run] [--check] [--link-popular] [--no-shell] [--snap-only]
#
#   --dry-run       print planned changes, write nothing
#   --check         report drift, write nothing, exit non-zero if out of date
#   --link-popular  symlink the popular-models extension instead of copying it
#   --no-shell      do not touch the shell profile
#   --snap-only     install only pi-snap and its shell alias (legacy ./install.sh behavior)
#
# Never deletes user data. Existing targets are backed up before a write, and
# pre-existing directories are never replaced by symlinks (reported instead).

set -euo pipefail

DRY_RUN=0
CHECK=0
LINK_POPULAR=0
TOUCH_SHELL=1
SNAP_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --link-popular) LINK_POPULAR=1 ;;
    --no-shell) TOUCH_SHELL=0 ;;
    --snap-only) SNAP_ONLY=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "install-pi: unknown option: $arg" >&2; exit 2 ;;
  esac
done
export DRY_RUN CHECK

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$INSTALL_DIR/../.." && pwd -P)"
# shellcheck source=/dev/null
. "$INSTALL_DIR/lib.sh"

PI_DIR="$HOME/.pi/agent"
BIN_DIR="$PI_DIR/bin"
EXT_DIR="$PI_DIR/extensions"
SKILL_DIR="$PI_DIR/skills"
PI_JEV_PACKAGE="$PI_DIR/npm/node_modules/pi-jev"
SECRET_FILE="$HOME/.config/typesafe/jev_api_key"
SECRET_LINK="$PI_DIR/secrets/typesafe_api_key"

JEV_BEGIN="# BEGIN pi-sandbox jev-auto"
JEV_END="# END pi-sandbox jev-auto"
SNAP_BEGIN="# BEGIN pi-sandbox pi-snap"
SNAP_END="# END pi-sandbox pi-snap"

# Link a skill, but never replace a pre-existing real directory.
link_skill() {
  local src="$1" target="$2" label="$3"
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    warn "skip $label: existing directory (migrate to a common-skill link separately)"
    return 0
  fi
  install_link "$src" "$target" "$label"
}

if [ "$SNAP_ONLY" = 1 ]; then
  info "Installing only pi-snap (legacy root install behavior)"
  install_copy "$REPO_ROOT/tools/pi-snap" "$BIN_DIR/pi-snap" 0755 "pi-snap"
  if [ -f "$HOME/.bashrc" ] && grep -qF "$SNAP_BEGIN" "$HOME/.bashrc"; then
    install_block "$HOME/.bashrc" "$REPO_ROOT/config/pi/shell/pi-snap.sh" \
      "$SNAP_BEGIN" "$SNAP_END" "bashrc pi-snap block"
  elif [ -f "$HOME/.bashrc" ] && grep -q 'alias pi-snap=' "$HOME/.bashrc"; then
    info "unchanged: pi-snap alias already present (unmanaged; left as is)"
  else
    install_block "$HOME/.bashrc" "$REPO_ROOT/config/pi/shell/pi-snap.sh" \
      "$SNAP_BEGIN" "$SNAP_END" "bashrc pi-snap block"
  fi
  summary
  exit $?
fi

info "Pi config install into $PI_DIR"

# 1. Settings: merge managed keys only.
install_json_merge "$REPO_ROOT/config/pi/settings.template.json" "$PI_DIR/settings.json" "pi settings" \
  --append-path packages

# Ensure the package is physically installed, not only declared in settings.
if [ -f "$PI_JEV_PACKAGE/package.json" ]; then
  info "unchanged: Pi pi-jev package installed"
elif [ "$DRY_RUN" = 1 ]; then
  CHANGES=$((CHANGES + 1))
  info "would install: npm:pi-jev via pi"
elif [ "$CHECK" = 1 ]; then
  CHANGES=$((CHANGES + 1))
  warn "out of date: Pi pi-jev package is not installed"
else
  require_cmd pi
  pi install npm:pi-jev
  [ -f "$PI_JEV_PACKAGE/package.json" ] || die "pi install completed but pi-jev package is still missing"
  info "installed: Pi pi-jev package"
fi

# 2. Files.
install_copy "$REPO_ROOT/config/pi/AGENT.md" "$PI_DIR/AGENT.md" 0644 "AGENT.md"
install_copy "$REPO_ROOT/config/pi/keybindings.json" "$PI_DIR/keybindings.json" 0644 "keybindings.json"
install_copy "$REPO_ROOT/config/pi/extensions/delete-guard.ts" "$EXT_DIR/delete-guard.ts" 0644 "delete-guard.ts"
install_copy "$REPO_ROOT/config/pi/extensions/session-snapshot.ts" "$EXT_DIR/session-snapshot.ts" 0644 "session-snapshot.ts"
install_copy "$REPO_ROOT/tools/pi-snap" "$BIN_DIR/pi-snap" 0755 "pi-snap"

if [ "$LINK_POPULAR" = 1 ]; then
  if [ -d "$EXT_DIR/popular-models.ts" ] && [ ! -L "$EXT_DIR/popular-models.ts" ]; then
    warn "skip popular-models link: existing file (rerun without --link-popular or remove it yourself)"
  else
    install_link "$REPO_ROOT/tools/popular-models/popular-models.ts" "$EXT_DIR/popular-models.ts" "popular-models.ts (linked)"
  fi
else
  install_copy "$REPO_ROOT/tools/popular-models/popular-models.ts" "$EXT_DIR/popular-models.ts" 0644 "popular-models.ts"
fi

# 3. Shared skills (skip existing real directories).
link_skill "$REPO_ROOT/skills/common/catch-up-project" "$SKILL_DIR/catch-up-project" "common skill catch-up-project"
link_skill "$REPO_ROOT/skills/common/grill-me" "$SKILL_DIR/grill-me" "common skill grill-me"

# 4. Shell profile.
if [ "$TOUCH_SHELL" = 1 ]; then
  install_block "$HOME/.bashrc" "$REPO_ROOT/config/pi/shell/jev-auto.sh" \
    "$JEV_BEGIN" "$JEV_END" "bashrc PI_JEV_AUTO block"

  if [ -f "$HOME/.bashrc" ] && grep -qF "$SNAP_BEGIN" "$HOME/.bashrc"; then
    install_block "$HOME/.bashrc" "$REPO_ROOT/config/pi/shell/pi-snap.sh" \
      "$SNAP_BEGIN" "$SNAP_END" "bashrc pi-snap block"
  elif [ -f "$HOME/.bashrc" ] && grep -q 'alias pi-snap=' "$HOME/.bashrc"; then
    info "unchanged: pi-snap alias already present (unmanaged; left as is)"
  else
    install_block "$HOME/.bashrc" "$REPO_ROOT/config/pi/shell/pi-snap.sh" \
      "$SNAP_BEGIN" "$SNAP_END" "bashrc pi-snap block"
  fi
fi

# 5. TypeSafe secret: link only, never copy the value.
if [ -e "$SECRET_FILE" ]; then
  install_link "$SECRET_FILE" "$SECRET_LINK" "pi TypeSafe secret link"
else
  warn "skip TypeSafe secret link: $SECRET_FILE not found (create it with mode 600)"
fi

summary
