#!/usr/bin/env bash
# Install the read-only popular-models conversation-info extension into ~/.pi/agent/extensions/.
#
# Usage: install.sh [--link]
#   --link    Symlink the extension so repo edits apply immediately.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC="$REPO_DIR/popular-models.ts"
EXT_DIR="$HOME/.pi/agent/extensions"
DEST="$EXT_DIR/popular-models.ts"
MODE=copy

for arg in "$@"; do
  case "$arg" in
    --link) MODE=link ;;
    *) echo "install: unknown option: $arg" >&2; exit 2 ;;
  esac
done

[ -f "$SRC" ] || { echo "install: error: $SRC not found" >&2; exit 1; }
mkdir -p "$EXT_DIR"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  cp -p "$DEST" "$DEST.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  rm -f "$DEST"
fi

if [ "$MODE" = link ]; then
  ln -s "$SRC" "$DEST"
  echo "install: linked: $DEST -> $SRC"
else
  cp "$SRC" "$DEST"
  echo "install: copied: $DEST"
fi

echo "install: done. The top ten list is added to the conversation on startup and new sessions."
