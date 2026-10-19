#!/usr/bin/env bash
# install-agy.sh — install/merge the repo-managed Antigravity configuration.
#
# Usage:
#   install-agy.sh [--dry-run] [--check] [--build]
#
#   --dry-run  print planned changes, write nothing
#   --check    report drift, write nothing, exit non-zero if out of date
#   --build    rebuild/typecheck/test the Jev MCP adapter even if dist exists
#
# Manages: CLI settings merge, keybindings merge, the Jev plugin (rule + hooks),
# removal of the legacy managed GEMINI.md rule block, the MCP registration, and
# the adapter build. Model, deny rules, non-workspace access, and trusted
# workspaces are preserved; only the two named Jev MCP tools are added to the
# existing permissions.allow array.

set -euo pipefail

DRY_RUN=0
CHECK=0
BUILD=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --build) BUILD=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "install-agy: unknown option: $arg" >&2; exit 2 ;;
  esac
done
export DRY_RUN CHECK

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$INSTALL_DIR/../.." && pwd -P)"
# shellcheck source=/dev/null
. "$INSTALL_DIR/lib.sh"

AGY_STATE="$HOME/.gemini/antigravity-cli"
AGY_CONFIG="$HOME/.gemini/config"
AGY_SETTINGS="$AGY_STATE/settings.json"
AGY_KEYBINDINGS="$AGY_STATE/keybindings.json"
PLUGIN_SOURCE="$REPO_ROOT/config/agy/plugin/pi-sandbox-jev"
PLUGIN_TARGET="$AGY_CONFIG/plugins/pi-sandbox-jev"
GEMINI="$HOME/.gemini/GEMINI.md"

MCP_DIR="$REPO_ROOT/tools/antigravity/jev-mcp"
MCP_ENTRY="$MCP_DIR/dist/index.js"
MCP_NAME="pi-sandbox-jev"
DEFAULT_KEY_FILE="$HOME/.config/typesafe/jev_api_key"

RULE_BEGIN="<!-- BEGIN pi-sandbox Jev-assisted development workflow -->"
RULE_END="<!-- END pi-sandbox Jev-assisted development workflow -->"

info "Antigravity config install into $AGY_STATE"

# 1. CLI settings: merge managed keys only.
install_json_merge "$REPO_ROOT/config/agy/settings.template.json" "$AGY_SETTINGS" "agy settings" \
  --append-path permissions.allow

# 2. Keybindings: merge managed keys only, preserving user overrides.
install_json_merge "$REPO_ROOT/config/agy/keybindings.template.json" "$AGY_KEYBINDINGS" "agy keybindings"

# 3. Register the installed plugin path and explicitly enable the plugin.
# `plugins.json` scans one level under the config/plugins directory.
install_json_merge "$REPO_ROOT/config/agy/plugins.template.json" "$AGY_CONFIG/plugins.json" "agy plugin discovery" \
  --append-path entries
install_json_merge "$REPO_ROOT/config/agy/plugin-enable.template.json" "$AGY_CONFIG/config.json" "agy plugin enablement"

# 4. Plugin bundle: always-on rule + hooks, enabled by default.
install_link "$PLUGIN_SOURCE" "$PLUGIN_TARGET" "agy Jev plugin"

# 5. Migrate the old hand-edited rule block out of GEMINI.md (idempotent).
remove_block "$GEMINI" "$RULE_BEGIN" "$RULE_END" "GEMINI.md legacy Jev rule block"

# 6. MCP permission + registration: grant only this named Jev server and keep
# an existing registration untouched; register only when missing.
if command -v agy >/dev/null 2>&1; then
  MCP_LIST="$(agy mcp list 2>/dev/null)" || die "could not query AGY MCP registrations"
  if printf '%s\n' "$MCP_LIST" | grep -Fq "$MCP_NAME"; then
    info "unchanged: agy MCP server '$MCP_NAME'"
  elif [ "$DRY_RUN" = 1 ] || [ "$CHECK" = 1 ]; then
    CHANGES=$((CHANGES + 1))
    if [ "$DRY_RUN" = 1 ]; then info "would register: agy MCP server '$MCP_NAME'"; else warn "out of date: agy MCP server '$MCP_NAME'"; fi
  else
    CHANGES=$((CHANGES + 1))
    if [ -n "${TYPESAFE_API_KEY_FILE:-}" ]; then
      agy mcp add --env "TYPESAFE_API_KEY_FILE=$TYPESAFE_API_KEY_FILE" "$MCP_NAME" node "$MCP_ENTRY"
    elif [ -f "$DEFAULT_KEY_FILE" ]; then
      agy mcp add --env "TYPESAFE_API_KEY_FILE=$DEFAULT_KEY_FILE" "$MCP_NAME" node "$MCP_ENTRY"
    else
      agy mcp add "$MCP_NAME" node "$MCP_ENTRY"
    fi
    info "registered: agy MCP server '$MCP_NAME'"
  fi
else
  die "agy CLI not found; install Antigravity before installing its configuration"
fi

# 7. Adapter build/test (only when needed or requested).
if [ "$BUILD" != 1 ] && [ -f "$MCP_ENTRY" ]; then
  info "unchanged: jev-mcp adapter build (dist present; use --build to rebuild)"
elif [ "$DRY_RUN" = 1 ]; then
  CHANGES=$((CHANGES + 1))
  info "would build: jev-mcp adapter"
elif [ "$CHECK" = 1 ]; then
  CHANGES=$((CHANGES + 1))
  warn "out of date: jev-mcp adapter build"
else
  (cd "$MCP_DIR" && npm ci && npm run typecheck && npm test && npm run build)
  info "built: jev-mcp adapter"
fi

summary
