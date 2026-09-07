# Spec — Helper Scripts & Shell Alias

## 1. `~/.pi/agent/bin/pi-snap` (custom)

Hardlink snapshot script — the rollback layer of the daily sandbox.

```
Usage: pi-snap [project-dir]     (defaults to $PWD)
```

### Behavior

1. Canonicalize the project dir.
2. Project key = absolute path with `/` → `_` (e.g. `/home/x/y` → `_home_x_y`).
3. Snapshot root = `~/.pi/snapshots/<key>/` (override with `PI_SNAP_ROOT`).
4. Snapshot into `snap-<timestamp>/` (nanosecond timestamp, collision-free).
5. `rsync -a --delete --link-dest=<latest>` — unchanged files are hardlinked,
   so later snapshots cost only changed-file disk space.
6. Repoint `latest` symlink to the new snapshot.
7. Prune to last **10** snapshots (`PI_SNAP_KEEP` overrides).

### Exclusions (regenerable artifacts, never snapshotted)

`.git`, `node_modules`, `.venv`, `venv`, `__pycache__`, `*.pyc`, `build`,
`install`, `log`, `dist`, `target`, `.uv`, `.cache`

### Invocation

- Automatic: `session-snapshot` extension on `session_start`.
- Manual: `pi-snap` (see alias below).

## 2. `~/.pi/agent/bin/fd`

Prebuilt `fd` binary (fast `find` alternative), present in the agent `bin/`.
Not user-modified.

## 3. `~/.bashrc` — shell alias

```bash
# pi-snap: manual checkpoint before risky pi operations (daily sandbox safety net)
alias pi-snap='~/.pi/agent/bin/pi-snap'
```

- Applies to the user's interactive shell (run `source ~/.bashrc` to load).
- Note: pi's own `bash` tool runs non-interactive and does **not** expand
  aliases; `pi-snap` is meant for the human, not the agent.
