# Pi Agent Daily-Tier Sandbox — Plan

Status: **approved design, not yet implemented**
Date: 2025-09-07
Scope: local development machine (Ubuntu 22.04, x86_64)

---

## 1. Goal

Give the **daily, trusted** use of `pi` a real safety net without migrating the
heavy host toolchain (nvm/Node, uv/Python, ROS2/Open3D/ceres) into a container.

This document is the design contract produced by the grill-me decision tree. It
records every decision, the rationale, and the concrete implementation plan.

---

## 2. Threat model (ranked)

We defend against, in priority order:

1. **c — credential exposure** (OpenRouter / Google keys in `~/.pi/agent/auth.json`)
2. **b — accidental host damage** (`rm -rf`, bad refactors, overwrites)
3. **d — unmonitored / scripted runs** (`pi -p`, non-interactive)
4. **a — untrusted repositories** (malicious code)

Ranking consequence: we optimize for secrets + accidental damage + unattended
runs, and we do **not** demand VM-grade isolation for malicious repos in the
daily tier.

---

## 3. Architecture: two tiers

| | Tier 1 — daily (this plan) | Tier 2 — untrusted/unmonitored (parked) |
|---|---|---|
| Toolchain | host nvm + uv + ROS2 (huge, mutable) | generic Node + Python image |
| Trust | own code | untrusted |
| Threat | accidental damage | malicious code, key theft |
| Boundary | **safety net, not security** | **real boundary** (Docker whole-process) |

**Fundamental tension:** full process isolation requires an independent copy of
the toolchain, and the mutable host toolchain is exactly what we isolate from.
Therefore "no rebuilds, always-matches-host" and "full isolation" cannot both be
maximized. Daily work needs the former; untrusted work needs the latter. Do not
force one tool to serve both.

**Decision:** daily work = host `pi` + guards; Docker tier deferred.

---

## 4. Daily-tier design

`pi` runs on the host (no migration), seeing nvm/uv/ROS exactly as the user does.
Safety comes from four layers:

1. **Guards** — `delete-guard` extension intercepts destructive operations.
2. **Rollback** — git (tracked files) + hardlink snapshots (everything incl. untracked).
3. **Input-loading guard** — project trust controls `.pi` resource loading.
4. **Credential hygiene** — leave `auth.json` on host (trusted code runs as user anyway).

### 4.1 Rollback: hardlink snapshots

- Tool: `rsync --link-dest` (hardlink snapshots; unchanged files cost ~0 bytes).
  `rsync` 3.2.7 is present on the host.
- Location: central `~/.pi/snapshots/<project-path>/`, **outside** the project so
  the agent cannot delete its own safety net.
- Exclusions (curated, per stack): `.git`, `node_modules`, `.venv`, `venv`,
  `__pycache__`, `*.pyc`, `build`, `install`, `log`, `dist`, `target`, `.uv`,
  `.cache`.
- Retention: keep last **10** snapshots per project; prune older on each run.
  (Count-based, not session-lifecycle-based — damage is often discovered after
  the session ends, so snapshots must outlive the session.)

### 4.2 Snapshot trigger

- **Automatic:** a pi extension hooks `session_start` (reasons `startup`, `new`,
  `resume`, `fork`; skip `reload`) and runs the snapshot script. ~60 s debounce
  avoids duplicates from quick re-fires.
- **Manual:** shell alias `pi-snap` for the moment right before authorizing a
  risky operation.

### 4.3 `delete-guard` extension (enhance existing)

Existing guards: `rm`, `rmdir`, `unlink`, `truncate -s 0`, `dd if=/dev/null`,
bare destructive redirects, `write`-overwrite. Pattern = confirm in interactive
UI, block in non-interactive.

Add guards for destructive git operations (git is the primary safety net, so it
must be protected):

- `git reset --hard`
- `git checkout -- <path>` / `git checkout -- .`
- `git restore <path>` / `git restore .`
- `git clean -fd` / `git clean -fdx`
- `git stash drop` / `git stash clear`

### 4.4 Project trust

Set `defaultProjectTrust: "ask"` explicitly in `settings.json` (it is already the
default). Per-project decisions are remembered in `~/.pi/agent/trust.json`, so it
prompts once per new project. This guards own repos against `.pi` files from a
poisoned PR.

### 4.5 Credentials

No change for daily tier. Keys stay in `~/.pi/agent/auth.json`. Scoped/rotatable
keys belong to the Docker tier.

---

## 5. Files to create / modify

| File | Action | Purpose |
|---|---|---|
| `~/.pi/agent/bin/pi-snap` | create (executable) | hardlink snapshot script |
| `~/.pi/agent/extensions/session-snapshot.ts` | create | auto-snapshot on `session_start` |
| `~/.pi/agent/extensions/delete-guard.ts` | edit | add destructive-git guards |
| `~/.pi/agent/settings.json` | edit | add `defaultProjectTrust: "ask"` |
| `~/.bashrc` | append | `alias pi-snap='~/.pi/agent/bin/pi-snap'` |

### 5.1 `pi-snap` script semantics

1. Resolve project dir = `$1` or current working directory.
2. Project key = absolute path with `/` → `_` (readable, collision-free).
3. `latest` symlink at `~/.pi/snapshots/<key>/latest`.
4. Snapshot into `~/.pi/snapshots/<key>/snap-<timestamp>/`:

   ```
   rsync -a --delete \
     --exclude=.git --exclude=node_modules --exclude=.venv --exclude=venv \
     --exclude=__pycache__ --exclude='*.pyc' --exclude=build --exclude=install \
     --exclude=log --exclude=dist --exclude=target --exclude=.uv --exclude=.cache \
     --link-dest="<abs latest>" "<src>/" "<dest>/"
   ```

5. Update `latest` symlink atomically.
6. Prune to last 10 `snap-*` entries.

### 5.2 `session-snapshot.ts` semantics

- Subscribe to `session_start`.
- Skip `reason === "reload"`.
- Debounce: skip if `latest` snapshot mtime < 60 s old.
- Spawn `pi-snap <cwd>` via `child_process`.
- Report success/failure via `ctx.ui.notify`.

### 5.3 `delete-guard.ts` additions

Follow the existing pattern: regex-detect each git command; `ctx.ui.confirm` when
`ctx.hasUI`, else block with a clear reason. Add cases before the existing
`return undefined` tail.

### 5.4 `settings.json`

```json
{
  "lastChangelogVersion": "0.85.1",
  "defaultProvider": "openrouter",
  "defaultModel": "deepseek/deepseek-v4-pro-0813",
  "defaultThinkingLevel": "high",
  "defaultProjectTrust": "ask"
}
```

---

## 6. Verification plan

1. `pi-snap` dry-run in `~/Code/pi_sandbox` — creates one snapshot,
   `latest` symlink points to it, no repo content modified.
2. Run `pi-snap` again — second snapshot is hardlinked (fast, minimal extra disk).
3. Confirm pruning: create >10 snapshots in a scratch dir, verify only 10 remain.
4. Load `pi` — verify `session_start` snapshot fires and notifies.
5. Trigger each new `delete-guard` rule interactively and confirm prompts appear;
   run non-interactively and confirm blocks.

---

## 7. Parked (future) work — Tier 2

Whole-process Docker for untrusted/unmonitored repos:

- Thin image: `node:24-bookworm-slim` + pi + `bash`/`git`/`ripgrep`.
- Do **not** mount host `~/.pi/agent`; pass a dedicated scoped key via `-e`.
- Restrict egress to OpenRouter/Google endpoints.
- Optional upgrade path: Gondolin micro-VM (needs Node ≥ 23.6 + QEMU) if Tier 2
  must also hold keys on the host.
