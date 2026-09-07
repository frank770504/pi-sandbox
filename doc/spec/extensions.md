# Spec — Extensions

Source: `~/.pi/agent/extensions/`

## 1. `delete-guard.ts` — destructive-operation guard

Intercepts tool calls and blocks/prompts destructive operations. Behavior:

- Interactive (`ctx.hasUI` true): `ctx.ui.confirm` prompt; user may allow or deny.
- Non-interactive (print/JSON, no UI): **block by default** with a reason.

### Guarded operations

| Category | Patterns |
|---|---|
| Nuclear rm | `rm -rf /` / `rm -r /` — always blocked, no prompt |
| Recursive rm | `rm -r*`, `rm --recursive`, `rm --force` |
| Bare rm | `rm [-f] <path>` |
| rmdir / unlink | `rmdir`, `unlink` |
| Truncate | `truncate -s 0 <file>` |
| Zero-file | `dd if=/dev/null of=<file>` |
| Redirect truncation | bare `> <existing-file>` |
| Write-overwrite | `write` tool targeting an existing file |
| **git reset --hard** | `git reset --hard [ref]` |
| **git checkout --** | `git checkout -- <paths>` (discard working-tree changes) |
| **git restore** | `git restore <paths>` without `--staged` (discard working-tree changes) |
| **git clean -f** | `git clean -f/-fd/-fdx/--force` (delete untracked files) |
| **git stash drop/clear** | `git stash drop` / `git stash clear` |

The git guards were added as part of the daily-sandbox plan because git is the
primary rollback layer; see `doc/plan/archive/pi-sandbox-daily-tier-plan.md`.

## 2. `session-snapshot.ts` — rollback snapshot on session start

Hooks the `session_start` event and takes a hardlink snapshot of the project
before work begins.

- Skips `reason === "reload"` (not a work boundary).
- Debounces: skips if the `latest` snapshot symlink is < 60 s old (`lstatSync`,
  not `statSync` — `rsync -a` preserves the target dir's mtime).
- Spawns `~/.pi/agent/bin/pi-snap <cwd>` and reports success/failure via
  `ctx.ui.notify`.
- Snapshot mechanics (script) documented in [bin-and-shell.md](bin-and-shell.md).

### Interaction with the 3-step workflow

`session-snapshot` fires automatically at session start regardless of the
Align→Plan→Wait flow; it only *reads* the project (plus writes under
`~/.pi/snapshots/`), so it does not violate the AGENT.md no-edit-before-approval
rule.
