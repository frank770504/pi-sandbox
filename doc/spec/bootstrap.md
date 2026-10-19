# Bootstrap Specification — Recreate the Pi + AGY Environment

This document is the detailed procedure behind the repository [README](../../README.md). It covers repo-managed configuration only; provider login, credential creation, and trust decisions remain machine-local.

## Prerequisites

Install using official sources before running the full installer:

| Tool | Minimum checked version / requirement | Why |
|---|---|---|
| Pi | 1.3.0 | Coding agent and package loader |
| Antigravity CLI (`agy`) | 1.4.0 | AGY settings, skills, hooks, plugins, MCP |
| Node.js | 20 | Pi and AGY MCP runtime |
| npm | available | Pi Jev and local AGY MCP package installs |
| Git | available | pinned third-party skills |
| Python 3 | available | safe JSON merge and verifier |
| rsync | available | `pi-snap` snapshots |
| Bash | available | installers |

The version checks are in `tools/install/verify.py`. The setup itself does not download or install Pi or AGY. A clean install needs npm registry access for `pi-jev` and the local AGY adapter, plus public Git access for pinned external skills unless `--no-external` is used.

## User setup before installing

1. Log in to model providers in Pi and AGY using their supported login flows.
2. Create `~/.config/typesafe/jev_api_key` with a TypeSafe key and mode `0600`. Do not put credentials in this repo. The same file is referenced by Pi's secret symlink and AGY's MCP environment.
3. Review any project trust prompt on first use. Trust decisions are not copied from the source machine.
4. Ensure the official CLI executables are on `PATH` in the shell that will run the installer.

## Install

```bash
./install.sh --all
```

The orchestration order is Pi configuration, skills, then AGY configuration. It keeps the original no-argument command (`./install.sh`) as the pi-snap-only installer. The full installer:

- merges managed JSON settings and preserves unrelated keys;
- backs up changed files before writing and fails closed if a backup cannot be made;
- installs `npm:pi-jev` using Pi's package manager if it is declared but not installed;
- copies the Pi instructions, keybindings, extensions, Pi-snap and popular-models assets;
- enables `PI_JEV_AUTO=1` in a marked `.bashrc` block;
- links shared skills from `skills/common/` into both tools;
- clones external skills from the exact commits recorded in `tools/skills.lock`;
- configures the AGY settings, keybindings, Jev plugin, hooks, and MCP server;
- builds and tests the AGY adapter if the build artifact is missing.

### Existing skill directories

By default, an existing real directory or unrelated file at a managed skill path is preserved and causes a nonzero installer result. To migrate the four original common skills, explicitly run:

```bash
./install.sh --all --migrate-existing
```

This moves each old directory intact to `~/.pi-sandbox-backups/skills/` (backup directory mode `0700`) and then creates the repo-managed symlink. It does not discard the old contents. Inspect the backups before removing them manually.

External skill clones default to `~/Code/3party`. Override their parent directory with `PI_SANDBOX_SKILLS_ROOT`. Use `--no-external` to omit them; verification must also receive `--no-external` in that case.

The AGY installer leaves an existing same-named MCP entry untouched. If moving the repo changes the adapter path, `verify.sh` reports the mismatch; update the entry explicitly with `agy mcp add` and the new repo path. Keep the API key value out of command arguments.

## Verify

```bash
tools/install/verify.sh
```

The verifier checks:

- CLI/runtime prerequisites and minimum versions;
- managed Pi settings, files, package declaration/install, Pi-snap and `PI_JEV_AUTO`;
- AGY editor/settings, required keybindings, plugin discovery/enablement, hooks, Jev MCP permission and registration;
- common skill links and pinned external clone state;
- the Pi secret symlink and TypeSafe key-file owner/mode;
- component installer `--check` results.

It never reads or prints secret values. Missing credentials are warnings by default; `--strict-credentials` makes them failures. It does not call TypeSafe. A live Jev smoke test is a separate, explicit action because it transmits the supplied prompt/state to the service.

## Automatic Jev checks

- **Pi:** in a new interactive Bash shell, start Pi and run `/jev status`. Expected: package configured, key origin resolved, and auto mode on. Routing uses one Jev request per prompt; it can be disabled in a shell with `PI_JEV_AUTO=0`.
- **AGY:** start a new session and check `/skills`, the MCP tool list, and a synthetic software-planning prompt. SessionStart and first-invocation hooks provide reminders; the plugin rule asks for Jev planning evaluations on development tasks. This is not a built-in guaranteed automatic router, so inspect whether the evaluation call succeeds. The rule is subject to model behavior and API availability.

## Non-destructive modes

```bash
./install.sh --all --dry-run
./install.sh --all --check
```

`--dry-run` previews writes; `--check` reports drift without writing. A nonzero result means an existing conflict, missing prerequisite, missing pinned clone, or drift needs attention. `tools/install/test-e2e.sh` tests the full orchestrator in an isolated temporary home with fake CLI shims and no credentials or TypeSafe calls.

## Deliberately unmanaged

- Provider auth, OAuth files, API keys, TypeSafe key contents, saved project trust, and AGY trusted workspaces.
- AGY model selection, unrelated permissions, and user-specific CLI state.
- Pi package caches, model catalogs, sessions, and snapshots.
- `fd`: the original machine has a host-installed `fd` binary; it is not currently provisioned by this repo. Install it separately if needed.

## Maintenance / recovery

The canonical sources are listed in `config/manifest.tsv`; the external pins are in `tools/skills.lock`. Re-run `./install.sh --all` to reconcile managed files. Existing config changes are backed up with timestamped `.bak.*` names. Skill migrations are backed up under `~/.pi-sandbox-backups/skills/`. No uninstall command removes user state automatically.
