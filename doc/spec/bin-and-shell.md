# Spec — Installers, Helpers, and Shell Configuration

## Root installer

`install.sh` is the compatibility entry point:

```bash
./install.sh                  # pi-snap only (legacy behavior)
./install.sh --all            # Pi + skills + AGY
./install.sh --all --dry-run
./install.sh --all --check
```

The full orchestration is backed by component installers in `tools/install/`. Run `tools/install/verify.sh` after setup.

## `pi-snap`

Canonical source: `tools/pi-snap`. It is installed to `~/.pi/agent/bin/pi-snap`. Commands include create, list, size, diff, restore, rm, prune, clean, and help. See the root README for examples and exclusions.

The installer adds a managed `pi-snap` alias block to `~/.bashrc` if there is no existing alias. Shell-profile changes are idempotent and backed up before changes.

## Shell automatic-Jev setting

`config/pi/shell/jev-auto.sh` is installed as a marked block in `~/.bashrc`:

```bash
export PI_JEV_AUTO=1
```

This enables Pi's automatic per-prompt Jev routing in new interactive Bash sessions. Set `PI_JEV_AUTO=0` in a shell to opt out for that session.

## Shared installer helpers

| File | Purpose |
|---|---|
| `tools/install/lib.sh` | backups, atomic writes, links, block and JSON merges, dry-run/check |
| `tools/install/merge-json.py` | managed-key JSON merge, optional additive list paths |
| `tools/install/merge-lines.py` | insert/replace/remove marked text blocks |
| `tools/install/install-pi.sh` | Pi settings, package, extensions, skills, shell, and pi-snap |
| `tools/install/install-agy.sh` | AGY settings/keybindings, Jev plugin/hooks/MCP and adapter build |
| `tools/install/install-skills.sh` | common skill links and pinned external skill provisioning |
| `tools/install/verify.sh` | verify versions, managed state, links, credentials mode, and drift |
| `tools/install/test*.sh` | merge, skill-migration, and temp-HOME end-to-end checks |

All installers provide dry-run/check modes where applicable. Existing file targets are backed up before writes; backup failure aborts the write. Existing real skill directories require the explicit `--migrate-existing` option and are moved intact outside skill-discovery paths.

## Optional host helper

The original machine has `fd` at `~/.pi/agent/bin/fd`; it is not currently distributed by this repository. Install an OS package such as `fd-find` separately if desired. It is not required by the Pi/AGY configuration installers.
