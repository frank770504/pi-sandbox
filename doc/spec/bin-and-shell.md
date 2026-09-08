# Spec — Helper Scripts & Shell Alias

## 1. `pi-snap` — snapshot + management CLI

Source of truth: `tools/pi-snap` (this repo). Installed to
`~/.pi/agent/bin/pi-snap` by `install.sh`.

```
Usage:
  pi-snap [dir]                     create a snapshot of dir (default: cwd)
  pi-snap list [dir|--all]          list snapshots (marker * = latest)
  pi-snap size [dir|--all]          disk usage, deduplicated per project
  pi-snap diff <snap> [dir]         preview what restore would change vs dir (default cwd)
  pi-snap restore <snap> [--into dir]  restore dir to snapshot (auto-snapshots first)
  pi-snap rm <snap>                 delete one snapshot (repairs latest)
  pi-snap prune [N] [dir]           prune to N snapshots (default 10)
  pi-snap clean [--all]             remove orphaned projects; --all wipes the store
  pi-snap help                      this help
```

### Snapshot reference (`<snap>`)

`latest`, a snapshot basename within the current project, or an absolute path to
a snapshot directory. Refuses anything outside the snapshot store.

### Store layout

```
~/.pi/snapshots/<project-key>/
  .source                       # canonical source path (metadata)
  latest -> snap-<newest>       # symlink
  snap-<timestamp>/             # hardlink snapshots
```

- Project key = absolute path with `/` → `_` (e.g. `/home/x/y` → `_home_x_y`).
- Exclusions (never snapshotted): `.git`, `node_modules`, `.venv`, `venv`,
  `__pycache__`, `*.pyc`, `build`, `install`, `log`, `dist`, `target`, `.uv`,
  `.cache`.
- Retention: last **10** per project (auto-pruned on create; `prune` overrides).

### Safety properties

- `restore` always takes a fresh snapshot of the target **first**, so restore is
  reversible; the pre-restore state becomes the newest snapshot.
- `restore` uses the same exclusions + `--delete`, so excluded dirs (`.git`,
  `node_modules`, …) are never deleted, while everything else is made to match
  the snapshot.
- `rm`/`clean` confirm before deleting unless `-y`/`--yes`; `rm` only touches
  paths under the store (containment check).
- `clean` removes only projects whose recorded `.source` no longer exists.
  Legacy dirs without `.source` are skipped (use `--all` to force).

### Environment

- `PI_SNAP_ROOT` — store location (default `~/.pi/snapshots`).
- `PI_SNAP_KEEP` — default snapshot count (default `10`).

## 2. `install.sh` (repo root)

Installs `tools/pi-snap` → `~/.pi/agent/bin/pi-snap` (timestamped backup of any
existing file), `chmod +x`, and adds the `pi-snap` alias to `~/.bashrc`
idempotently.

```bash
./install.sh
```

## 3. `~/.pi/agent/bin/fd`

Prebuilt `fd` binary (fast `find` alternative). Not user-modified.

## 4. `~/.bashrc` — shell alias

```bash
# pi-snap: snapshot + management for pi's daily safety net
alias pi-snap='~/.pi/agent/bin/pi-snap'
```

- Applies to the user's interactive shell (`source ~/.bashrc` to load).
- pi's own `bash` tool is non-interactive and does not expand aliases; `pi-snap`
  is meant for the human, not the agent.
