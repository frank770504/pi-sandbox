#!/usr/bin/env bash
# lib.sh — shared helpers for the pi-sandbox installers.
#
# Source this file from an installer that has already set shell options:
#   set -euo pipefail
#   REPO_ROOT=...
#   . "$REPO_ROOT/tools/install/lib.sh"
#
# Global flags (set by the caller before calling helpers):
#   DRY_RUN=1  print planned changes, write nothing
#   CHECK=1    report changes, write nothing, exit non-zero at the end
#
# Helpers never delete files. Existing targets are backed up before a write.

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="${REPO_ROOT:-$(cd "$INSTALL_DIR/../.." && pwd -P)}"

: "${DRY_RUN:=0}"
: "${CHECK:=0}"
: "${CHANGES:=0}"

info() { printf '[info] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*" >&2; }
die() { printf '[error] %s\n' "$*" >&2; exit 1; }

# Expand a leading ~ or ~/ to $HOME. Other paths are returned unchanged.
expand_home() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# Timestamped copy of an existing file or symlink. No-op for missing targets.
backup_file() {
  local target="$1"
  [ -e "$target" ] || [ -L "$target" ] || return 0
  local stamp backup suffix=0
  stamp="$(date +%Y%m%d-%H%M%S)-$$"
  backup="$target.bak.$stamp"
  while [ -e "$backup" ] || [ -L "$backup" ]; do
    suffix=$((suffix + 1))
    backup="$target.bak.$stamp-$suffix"
  done
  if cp -a "$target" "$backup" 2>/dev/null; then
    info "backup: $backup"
  else
    warn "could not back up $target"
    return 1
  fi
}

# Write stdin to target atomically. Creates parent directories as needed.
write_atomic() {
  local target="$1" mode="${2:-0644}" dir tmp
  dir="$(dirname "$target")"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.$(basename "$target").XXXXXX")" || die "mktemp failed for $target"
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$target"
}

# Merge managed keys from a template JSON into a target JSON, preserving
# unrelated keys. On change: back up, then write atomically.
install_json_merge() {
  local template="$1" target="$2" label="${3:-$2}" rc=0
  shift 3 || true
  local -a merge_options=("$@")
  require_cmd python3
  [ -f "$template" ] || die "template not found: $template"

  python3 "$INSTALL_DIR/merge-json.py" "${merge_options[@]}" --check "$template" "$target" || rc=$?
  case "$rc" in
    0) info "unchanged: $label"; return 0 ;;
    3) : ;;
    *) die "invalid input while merging $label" ;;
  esac

  CHANGES=$((CHANGES + 1))
  if [ "$DRY_RUN" = 1 ]; then
    info "would update: $label"
    return 0
  fi
  if [ "$CHECK" = 1 ]; then
    warn "out of date: $label"
    return 0
  fi
  backup_file "$target" || die "backup failed; refusing to update $target"
  python3 "$INSTALL_DIR/merge-json.py" "${merge_options[@]}" "$template" "$target" | write_atomic "$target" 0644
  info "updated: $label"
}

# Insert or replace a managed marker block inside a text file.
install_block() {
  local target="$1" block_file="$2" begin="$3" end="$4" label="${5:-$target}" rc=0
  require_cmd python3
  [ -f "$block_file" ] || die "block file not found: $block_file"

  python3 "$INSTALL_DIR/merge-lines.py" --check \
    --file "$target" --block-file "$block_file" \
    --begin "$begin" --end "$end" || rc=$?
  case "$rc" in
    0) info "unchanged: $label"; return 0 ;;
    3) : ;;
    *) die "invalid input while updating $label" ;;
  esac

  CHANGES=$((CHANGES + 1))
  if [ "$DRY_RUN" = 1 ]; then
    info "would update: $label"
    return 0
  fi
  if [ "$CHECK" = 1 ]; then
    warn "out of date: $label"
    return 0
  fi
  backup_file "$target" || die "backup failed; refusing to update $target"
  python3 "$INSTALL_DIR/merge-lines.py" \
    --file "$target" --block-file "$block_file" \
    --begin "$begin" --end "$end" | write_atomic "$target" 0644
  info "updated: $label"
}

# Remove a managed marker block from a text file. No-op when already absent.
remove_block() {
  local target="$1" begin="$2" end="$3" label="${4:-$target}" rc=0
  require_cmd python3
  if [ ! -f "$target" ]; then
    info "unchanged: $label (missing)"
    return 0
  fi

  python3 "$INSTALL_DIR/merge-lines.py" --check --remove \
    --file "$target" --begin "$begin" --end "$end" || rc=$?
  case "$rc" in
    0) info "unchanged: $label"; return 0 ;;
    3) : ;;
    *) die "invalid input while removing block from $label" ;;
  esac

  CHANGES=$((CHANGES + 1))
  if [ "$DRY_RUN" = 1 ]; then
    info "would remove block: $label"
    return 0
  fi
  if [ "$CHECK" = 1 ]; then
    warn "out of date: $label"
    return 0
  fi
  backup_file "$target" || die "backup failed; refusing to update $target"
  python3 "$INSTALL_DIR/merge-lines.py" --remove \
    --file "$target" --begin "$begin" --end "$end" | write_atomic "$target" 0644
  info "removed block: $label"
}

# Copy a file (or symlink source) to a target. Existing targets are backed up.
install_copy() {
  local src="$1" target="$2" mode="${3:-0644}" label="${4:-$2}"
  [ -e "$src" ] || die "source not found: $src"
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    warn "refusing to overwrite directory: $target"
    return 1
  fi

  if [ -L "$target" ] && [ "$(readlink -f "$target" 2>/dev/null)" = "$(readlink -f "$src" 2>/dev/null)" ]; then
    info "unchanged: $label"; return 0
  fi
  if [ -f "$target" ] && [ ! -L "$target" ] && cmp -s "$src" "$target"; then
    info "unchanged: $label"; return 0
  fi

  CHANGES=$((CHANGES + 1))
  if [ "$DRY_RUN" = 1 ]; then info "would install: $label"; return 0; fi
  if [ "$CHECK" = 1 ]; then warn "out of date: $label"; return 0; fi
  backup_file "$target" || die "backup failed; refusing to update $target"
  write_atomic "$target" "$mode" < "$src"
  info "installed: $label"
}

# Create or repoint a symlink. Never deletes the target's own content.
install_link() {
  local src="$1" target="$2" label="${3:-$2}"
  [ -e "$src" ] || die "source not found: $src"
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    warn "refusing to replace directory with symlink: $target"
    return 1
  fi

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    info "unchanged: $label"; return 0
  fi
  CHANGES=$((CHANGES + 1))
  if [ "$DRY_RUN" = 1 ]; then info "would link: $label -> $src"; return 0; fi
  if [ "$CHECK" = 1 ]; then warn "out of date: $label"; return 0; fi
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    backup_file "$target" || die "backup failed; refusing to update $target"
  fi
  ln -sfn "$src" "$target"
  info "linked: $label -> $src"
}

summary() {
  if [ "$CHECK" = 1 ] && [ "$CHANGES" -gt 0 ]; then
    warn "$CHANGES item(s) out of date"
    return 1
  fi
  if [ "$DRY_RUN" = 1 ]; then
    if [ "$CHANGES" -eq 0 ]; then
      info "everything already up to date"
    else
      info "$CHANGES item(s) would change"
    fi
    return 0
  fi
  if [ "$CHANGES" -eq 0 ]; then
    info "everything already up to date"
  else
    info "$CHANGES item(s) handled"
  fi
  return 0
}
