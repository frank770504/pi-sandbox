# Spec — Extensions

Source: `~/.pi/agent/extensions/` (with `popular-models.ts` vendored under `tools/popular-models/`).

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

## 3. `popular-models.ts` — read-only top-model conversation info

Vendored in `tools/popular-models/` with an installer. Install with:

```bash
bash tools/popular-models/install.sh          # copy into ~/.pi/agent/extensions/
bash tools/popular-models/install.sh --link   # symlink the repo source
```

On startup and for each newly created session, a visible informational message
is added to the conversation with the **top ten OpenRouter models by weekly
tool-call usage**. It scrolls up with the transcript and participates in model
context, but does not trigger an agent turn. The ranking is read-only: there is
no selection dialog, and it never changes the active model. Each row includes
the model ID, weekly usage, input/output prices in USD per million tokens, and
context length when available. Missing catalog fields are marked `n/a`. A model
change invalidates any in-flight
ranking load; a message already added remains in conversation history. The list
is not added on reload, resume, fork, or in modes without a UI.

The ranking comes from
`https://openrouter.ai/api/frontend/v1/rankings/tools`; the latest weekly bucket
is sorted by usage, the `Others` bucket is ignored, and dated point releases are
deduplicated by their base model ID. Model names, token prices, and context
length come from `https://openrouter.ai/api/v1/models`; prices are normalized
from USD per token to USD per million tokens. Ranking data is cached at
`~/.pi/agent/popular-models-cache.json` and model details at
`~/.pi/agent/popular-models-metadata-cache.json`, both for 12 hours. When a
refresh fails, stale cached data is used when available; missing model details do
not prevent the ranking from appearing.
