# Personal setting

This repo is made to track my personal settings.
If anyone has better ideas and happens to have time to talk to me,
please leave a message. Thanks.

# pi-sandbox

Custom [pi](https://github.com/earendil-works/pi-mono) configuration and a
rollback safety net for daily development. `pi` has no built-in sandbox — this
repo documents the custom config on this machine and provides `pi-snap`, a
hardlink-snapshot tool that lets you undo accidental damage.

## What's here

```
.
├── install.sh                      # install pi-snap + shell alias
├── tools/
│   ├── pi-snap                     # snapshot + management CLI (source of truth)
│   └── antigravity/                # AGY Jev MCP adapter, skill source, installer
└── doc/
    ├── plan/archive/…              # approved sandbox design (decision record)
    └── spec/…                      # specs of all custom pi config on this machine
```

## What this is for

- **Daily work** (your own trusted repos): run `pi` normally on the host, with
  a safety net made of two layers — git (tracked files) and `pi-snap` hardlink
  snapshots (everything, including untracked files).
- **Untrusted / unmonitored work**: not covered here; see
  `doc/plan/archive/pi-sandbox-daily-tier-plan.md` for the parked Docker tier.

Read the full rationale in the [plan](doc/plan/archive/pi-sandbox-daily-tier-plan.md)
and the per-file specs in [doc/spec/](doc/spec/README.md).

---

## Install `pi-snap`

```bash
./install.sh
source ~/.bashrc          # activate the pi-snap alias in this shell
pi-snap help
```

`install.sh` copies `tools/pi-snap` to `~/.pi/agent/bin/pi-snap` (backing up any
existing file), makes it executable, and adds the `pi-snap` alias to `~/.bashrc`
idempotently.

---

## Install the AGY Jev workflow

```bash
bash tools/antigravity/install-agy.sh
agy mcp list
```

This installs a repo-managed Antigravity skill and registers a local stdio MCP
adapter for TypeSafe Jev. Configure `TYPESAFE_API_KEY` in the environment used
to launch `agy`, or set `TYPESAFE_API_KEY_FILE` to an owner-only secret file
before running the installer. It stores only that file path, never the key, in
AGY MCP configuration or the repository.
See [antigravity.md](doc/spec/antigravity.md) for details.

---

## Using `pi-snap`

Snapshots live in `~/.pi/snapshots/<project>/`, keep the last **10** per project
(older ones are pruned automatically), and exclude regenerable junk (`.git`,
`node_modules`, `.venv`, `build`, `install`, `log`, `dist`, `target`, `__pycache__`,
`*.pyc`, `.uv`, `.cache`). Unchanged files are hardlinked, so later snapshots
cost almost nothing.

### Commands

| Command | Purpose |
|---|---|
| `pi-snap [dir]` | create a snapshot of `dir` (default: current dir) |
| `pi-snap list [dir\|--all]` | list snapshots (`*` = latest) |
| `pi-snap size [dir\|--all]` | disk usage, deduplicated |
| `pi-snap diff <snap> [dir]` | preview what a restore would change |
| `pi-snap restore <snap> [--into dir]` | restore a snapshot (auto-snapshots first) |
| `pi-snap rm <snap>` | delete one snapshot (repairs `latest`) |
| `pi-snap prune [N] [dir]` | prune to N snapshots (default 10) |
| `pi-snap clean [--all]` | remove orphaned projects; `--all` wipes the store |

- `<snap>` is `latest`, a snapshot basename in the current project, or an
  absolute path to a snapshot directory.
- `-y` / `--yes` skips confirmation prompts (`rm`, `clean`).

### Examples

```bash
cd ~/Code/myproject
pi-snap                       # checkpoint before a risky change
# …ask pi to do the change…
pi-snap list                  # see snapshots
pi-snap diff latest           # see what changed since the checkpoint
pi-snap restore latest        # undo it (current state is snapshotted first)
pi-snap size --all            # how much disk the whole store uses
```

### Typical rollback workflow

1. `pi-snap` before telling pi to do something destructive.
2. Review the result with `pi-snap diff latest`.
3. If it went wrong: `pi-snap restore latest` — the pre-restore state is
   preserved as a new snapshot, so the restore itself is reversible.

**Safety guarantees:** `restore` always snapshots the current state first;
`restore` never deletes excluded dirs (`.git`, `node_modules`, …); `rm` refuses
any path outside `~/.pi/snapshots`.

### Environment

| Variable | Default | Meaning |
|---|---|---|
| `PI_SNAP_ROOT` | `~/.pi/snapshots` | snapshot store location |
| `PI_SNAP_KEEP` | `10` | snapshots kept per project |

---

## Configuring pi with this repo

`install.sh` handles the `pi-snap` tool. The rest of pi's custom config lives in
`~/.pi/agent/` and is **documented** (not yet vendored) in `doc/spec/`:

| Spec | Live config file | What it configures |
|---|---|---|
| [settings.md](doc/spec/settings.md) | `~/.pi/agent/settings.json` | provider, model, thinking level, project trust, pi-jev package and setup |
| [agent-instructions.md](doc/spec/agent-instructions.md) | `~/.pi/agent/AGENT.md` | global system prompt (approval flow, repo-aware pi-jev planning loop, validation and delete rules) |
| [keybindings.md](doc/spec/keybindings.md) | `~/.pi/agent/keybindings.json` | vim-style TUI bindings |
| [extensions.md](doc/spec/extensions.md) | `~/.pi/agent/extensions/*.ts` | delete-guard, session-snapshot |
| [skills.md](doc/spec/skills.md) | `~/.pi/agent/skills/` | installed skills |
| [bin-and-shell.md](doc/spec/bin-and-shell.md) | `tools/pi-snap`, `~/.pi/agent/bin/`, `~/.bashrc` | pi-snap + alias |
| [antigravity.md](doc/spec/antigravity.md) | `~/.gemini/GEMINI.md`, AGY global skill, MCP config | Antigravity CLI Jev workflow and local TypeSafe MCP adapter |

These specs record the current config (with secrets redacted), so they are the
reference for replicating this setup on another Pi installation. For pi-jev,
add `npm:pi-jev` to the packages setting, configure a TypeSafe API key outside
the repo (see [settings.md](doc/spec/settings.md)), and copy the repo-aware
planning and validation workflow from [agent-instructions.md](doc/spec/agent-instructions.md)
into the global instructions file. Verify with `/jev status`. To apply a spec,
create/copy the documented content into the corresponding live file.

> **Note:** `session-snapshot` (see `doc/spec/extensions.md`) calls `pi-snap` on
> every session start, so snapshots happen automatically — you only need to run
> `pi-snap` manually for a checkpoint right before a specific risky step.

---

## Docs

- [Sandbox plan / decisions](doc/plan/archive/pi-sandbox-daily-tier-plan.md)
- [Spec index](doc/spec/README.md)
