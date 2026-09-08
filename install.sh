#!/usr/bin/env bash
# install.sh — install pi-snap into ~/.pi/agent/bin/ and add the shell alias.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC="$REPO_DIR/tools/pi-snap"
DEST_DIR="$HOME/.pi/agent/bin"
DEST="$DEST_DIR/pi-snap"

[ -f "$SRC" ] || { echo "install: error: $SRC not found" >&2; exit 1; }

mkdir -p "$DEST_DIR"

# Back up any existing install (timestamped) before overwriting.
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  cp -p "$DEST" "$DEST.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"

# Idempotent shell alias.
if ! grep -q "alias pi-snap=" "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'EOF'

# pi-snap: snapshot + management for pi's daily safety net
alias pi-snap='~/.pi/agent/bin/pi-snap'
EOF
  echo "install: added pi-snap alias to ~/.bashrc (run 'source ~/.bashrc' to use)"
fi

echo "install: done -> $DEST"
echo "install: try 'pi-snap help' (new shell: source ~/.bashrc)"
