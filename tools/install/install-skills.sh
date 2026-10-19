#!/usr/bin/env bash
# install-skills.sh — provision pinned third-party skills and install shared
# common skills into Pi and Antigravity.
#
# Usage:
#   install-skills.sh [--dry-run] [--check] [--no-external] [--migrate-existing]
#
# Existing real skill directories are preserved and cause a clear non-zero
# status unless --migrate-existing is explicitly provided. Migration moves the
# original directory intact to ~/.pi-sandbox-backups/skills before linking the
# repo-managed common skill. No skill content is discarded.

set -euo pipefail

DRY_RUN=0
CHECK=0
MIGRATE_EXISTING=0
INSTALL_EXTERNAL=1
CHANGES=0
BLOCKED=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --no-external) INSTALL_EXTERNAL=0 ;;
    --migrate-existing) MIGRATE_EXISTING=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "install-skills: unknown option: $arg" >&2; exit 2 ;;
  esac
done
export DRY_RUN CHECK CHANGES

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$INSTALL_DIR/../.." && pwd -P)"
# shellcheck source=/dev/null
. "$INSTALL_DIR/lib.sh"

PI_SKILLS="$HOME/.pi/agent/skills"
AGY_SKILLS="$HOME/.gemini/config/skills"
AGY_LEGACY_SKILLS="$HOME/.gemini/skills"
BACKUP_ROOT="$HOME/.pi-sandbox-backups/skills"
LOCK_FILE="$REPO_ROOT/tools/skills.lock"

require_cmd git
require_cmd python3
[ -f "$LOCK_FILE" ] || die "lock file not found: $LOCK_FILE"

# Clone/check out a locked repository only when the source is actually needed.
PREPARED_PATH=""
prepare_repo() {
  local name="$1" url="$2" commit="$3" clone_rel="$4"
  local clone_dir parent current origin
  clone_dir="$(expand_home "$clone_rel")"
  if [ -n "${PI_SANDBOX_SKILLS_ROOT:-}" ]; then
    clone_dir="$PI_SANDBOX_SKILLS_ROOT/$(basename "$clone_dir")"
  fi
  parent="$(dirname "$clone_dir")"

  if [ ! -e "$clone_dir" ]; then
    if [ "$DRY_RUN" = 1 ] || [ "$CHECK" = 1 ]; then
      CHANGES=$((CHANGES + 1))
      info "would clone pinned $name at $commit -> $clone_dir"
      PREPARED_PATH="$clone_dir"
      return 1
    fi
    mkdir -p "$parent"
    git clone "$url" "$clone_dir" || die "clone failed: $url"
  elif [ ! -d "$clone_dir/.git" ]; then
    die "clone path exists but is not a Git repository: $clone_dir"
  fi

  origin="$(git -C "$clone_dir" remote get-url origin 2>/dev/null || true)"
  [ "$origin" = "$url" ] || die "unexpected origin at $clone_dir (expected $url, got ${origin:-none})"
  if [ -n "$(git -C "$clone_dir" status --porcelain 2>/dev/null)" ]; then
    die "refusing to change dirty skill repository: $clone_dir"
  fi
  current="$(git -C "$clone_dir" rev-parse HEAD 2>/dev/null || true)"
  if [ "$current" != "$commit" ]; then
    if [ "$DRY_RUN" = 1 ] || [ "$CHECK" = 1 ]; then
      CHANGES=$((CHANGES + 1))
      info "would check out pinned $name commit $commit (currently ${current:-unknown})"
      PREPARED_PATH="$clone_dir"
      return 1
    fi
    git -C "$clone_dir" checkout --detach "$commit" || die "could not check out pinned commit $commit in $clone_dir"
    info "checked out $name at $commit"
  else
    info "verified $name at pinned commit $commit"
  fi
  PREPARED_PATH="$clone_dir"
}

same_link() {
  local target="$1" source="$2"
  [ -L "$target" ] && [ "$(readlink -f "$target" 2>/dev/null || true)" = "$(readlink -f "$source" 2>/dev/null || true)" ]
}

# Preserve an existing directory outside both skill discovery roots before
# installing a canonical link. This is opt-in because it changes live paths.
backup_existing_dir() {
  local target="$1" label="$2" backup
  backup="$BACKUP_ROOT/${label}-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$BACKUP_ROOT"
  chmod 700 "$BACKUP_ROOT"
  mv -- "$target" "$backup"
  info "preserved existing directory: $target -> $backup"
}

ensure_link() {
  local source="$1" target="$2" label="$3"
  if same_link "$target" "$source"; then
    info "unchanged: $label"
    return 0
  fi
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    if [ "$MIGRATE_EXISTING" != 1 ]; then
      warn "preserving existing directory; explicit --migrate-existing required: $target"
      BLOCKED=1
      return 0
    fi
    if [ "$DRY_RUN" = 1 ] || [ "$CHECK" = 1 ]; then
      CHANGES=$((CHANGES + 1))
      info "would preserve existing directory and link $label -> $source"
      return 0
    fi
    backup_existing_dir "$target" "$label"
  elif [ -e "$target" ] || [ -L "$target" ]; then
    # A file or unrelated symlink may contain user-managed content. Do not
    # overwrite it as part of skills provisioning.
    warn "preserving conflicting target; manual review required: $target"
    BLOCKED=1
    return 0
  fi

  CHANGES=$((CHANGES + 1))
  if [ "$DRY_RUN" = 1 ]; then
    info "would link: $label -> $source"
    return 0
  fi
  if [ "$CHECK" = 1 ]; then
    warn "out of date: $label"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  info "linked: $label -> $source"
}

ensure_common_agy() {
  local name="$1" source="$2" canonical legacy
  canonical="$AGY_SKILLS/$name"
  legacy="$AGY_LEGACY_SKILLS/$name"
  if same_link "$canonical" "$source"; then
    if [ -e "$legacy" ] || [ -L "$legacy" ]; then
      if same_link "$legacy" "$source"; then
        info "unchanged: AGY legacy common skill $name"
      elif [ "$MIGRATE_EXISTING" = 1 ]; then
        if [ "$DRY_RUN" = 1 ] || [ "$CHECK" = 1 ]; then
          CHANGES=$((CHANGES + 1))
          info "would preserve legacy AGY skill and remove duplicate discovery: $legacy"
        else
          backup_existing_dir "$legacy" "agy-$name-legacy"
        fi
      else
        warn "legacy AGY copy remains at $legacy; use --migrate-existing to preserve it outside skill discovery"
        BLOCKED=1
      fi
    fi
    return 0
  fi

  # If AGY already discovers this skill from its legacy root, do not add a
  # second discoverable copy under config/skills without explicit migration.
  if [ -e "$legacy" ] || [ -L "$legacy" ]; then
    if same_link "$legacy" "$source"; then
      info "unchanged: AGY common skill $name (legacy root already links to source)"
      return 0
    fi
    if [ "$MIGRATE_EXISTING" != 1 ]; then
      warn "preserving legacy AGY skill and avoiding a duplicate link: $legacy"
      BLOCKED=1
      return 0
    fi
    if [ "$DRY_RUN" = 1 ] || [ "$CHECK" = 1 ]; then
      CHANGES=$((CHANGES + 1))
      info "would preserve legacy AGY skill outside discovery and link common source: $name"
    else
      backup_existing_dir "$legacy" "agy-$name-legacy"
    fi
  fi
  ensure_link "$source" "$canonical" "AGY common skill $name"
}

# Provision common skills from their single repo source. Existing copies are
# never replaced without the explicit migration option.
for skill in catch-up-project grill-me; do
  source="$REPO_ROOT/skills/common/$skill"
  [ -f "$source/SKILL.md" ] || die "common skill source missing: $source/SKILL.md"
  ensure_link "$source" "$PI_SKILLS/$skill" "Pi common skill $skill"
  ensure_common_agy "$skill" "$source"
done

# Parse pinned external repositories, prepare each clone once, then link the
# requested skill subdirectory. A repository may have several skill rows.
if [ "$INSTALL_EXTERNAL" = 1 ]; then
  declare -A prepared=()
  while IFS=$'\t' read -r name url commit clone_rel source_subdir pi_link agy_link; do
    case "$name" in ''|'#'*) continue ;; esac
    if [[ "$source_subdir" = /* || "$source_subdir" == *".."* ]]; then
      die "unsafe source subdirectory in $LOCK_FILE: $source_subdir"
    fi
    if [ -z "${prepared[$clone_rel]+x}" ]; then
      if prepare_repo "$name" "$url" "$commit" "$clone_rel"; then
        clone_dir="$PREPARED_PATH"
        prepared[$clone_rel]="$clone_dir"
      else
        prepared[$clone_rel]=""
        continue
      fi
    else
      clone_dir="${prepared[$clone_rel]}"
    fi
    if [ "$source_subdir" = "." ]; then source="$clone_dir"; else source="$clone_dir/$source_subdir"; fi
    [ -f "$source/SKILL.md" ] || die "locked skill source missing SKILL.md: $source"

    if [ "$pi_link" != "-" ]; then
      ensure_link "$source" "$PI_SKILLS/$pi_link" "Pi external skill $name"
    fi
    if [ "$agy_link" != "-" ]; then
      canonical="$AGY_SKILLS/$agy_link"
      legacy="$AGY_LEGACY_SKILLS/$agy_link"
      if same_link "$canonical" "$source" || same_link "$legacy" "$source"; then
        info "unchanged: AGY external skill $name"
      elif [ -e "$legacy" ] || [ -L "$legacy" ]; then
        warn "preserving existing AGY external skill target: $legacy"
        BLOCKED=1
      else
        ensure_link "$source" "$canonical" "AGY external skill $name"
      fi
    fi
  done < "$LOCK_FILE"
fi

if [ "$CHECK" = 1 ] && [ "$CHANGES" -gt 0 ]; then
  warn "$CHANGES item(s) out of date"
  exit 1
fi
if [ "$BLOCKED" = 1 ]; then
  warn "some skill paths need explicit migration permission or manual review"
  exit 2
fi
if [ "$CHANGES" -eq 0 ]; then
  info "everything already up to date"
else
  info "$CHANGES item(s) handled"
fi
