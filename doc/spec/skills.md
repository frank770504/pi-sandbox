# Spec — Shared and Tool-Specific Skills

Common skill source of truth: [`skills/common/`](../../skills/common/). Install with `bash tools/install/install-skills.sh` or as part of `./install.sh --all`.

## Common skills

| Skill | Repo source | Pi target | AGY target |
|---|---|---|---|
| `catch-up-project` | `skills/common/catch-up-project/SKILL.md` | `~/.pi/agent/skills/catch-up-project` | `~/.gemini/config/skills/catch-up-project` |
| `grill-me` | `skills/common/grill-me/SKILL.md` | `~/.pi/agent/skills/grill-me` | `~/.gemini/config/skills/grill-me` |

The installer links both tools to the same source directories. It preserves existing real directories by default. `--migrate-existing` moves old directories intact to `~/.pi-sandbox-backups/skills/` before linking; the backup directory is private (mode `0700`) and outside AGY skill discovery paths.

## Pinned third-party skills

[`tools/skills.lock`](../../tools/skills.lock) records public Git URLs, exact commits, source subdirectories, and link targets. The installer verifies the URL, clean worktree, and pinned commit before creating links.

| Skill | Scope | Repo / commit |
|---|---|---|
| `code-review-excellence` | Pi and AGY | `awesome-skills/code-review-skill` at `eb12fb247ba09fd8a2bce0d1ecafa99df0bf4891` |
| `science-skills-common` | Pi | `google-deepmind/science-skills` at `0b72c64f63bc5ddf0e5fe96b8c3eb02e10fd5ef8` |
| `uv` | Pi | `google-deepmind/science-skills` at `0b72c64f63bc5ddf0e5fe96b8c3eb02e10fd5ef8` |

External clones default to `~/Code/3party`; set `PI_SANDBOX_SKILLS_ROOT` to choose another parent. Use `--no-external` to skip provisioning.

## Pi- and AGY-specific skills

- AGY Jev development skill: `config/agy/plugin/pi-sandbox-jev/skills/jev-development/SKILL.md`, loaded through the enabled plugin.
- Pi Jev workflow is documented in `config/pi/AGENT.md`; the Pi `pi-jev` package provides Jev commands and tools.
- The code-review skill is linked into both tools from one pinned clone.

## Safety and backups

A real directory at a managed skill target is never silently overwritten. Without `--migrate-existing`, the installer reports a conflict and exits nonzero. Migration preserves the old directory under `~/.pi-sandbox-backups/skills/`; no old content is discarded.
