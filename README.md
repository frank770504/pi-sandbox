# pi-sandbox — reproducible Pi + Antigravity setup

This repository tracks a personal development-agent environment for [Pi](https://github.com/earendil-works/pi-mono) and the Antigravity CLI (`agy`). Its installers recreate the repo-managed configuration, common skills, pinned third-party skills, Pi rollback helper, and the local TypeSafe Jev MCP adapter.

This is a **configuration and recovery setup, not a security sandbox**. It does not isolate trusted host processes from untrusted code.

## Quick start

### 1. Install prerequisites

Install and authenticate [Pi](https://github.com/earendil-works/pi-mono) and [Antigravity CLI](https://antigravity.google/docs/cli/reference) using their official instructions. The verifier expects:

- Pi **1.3.0 or newer**
- Antigravity CLI (`agy`) **1.4.0 or newer**
- Node.js **20 or newer** and npm
- Git, Python 3, and rsync

The repo installs `npm:pi-jev` through Pi and builds the local AGY MCP server from its locked npm dependencies; both need npm registry access on a clean setup. Third-party skill installation needs network access to the public Git repositories in [`tools/skills.lock`](tools/skills.lock).

### 2. Log in and configure TypeSafe credentials

Log in to the model providers you use from Pi and AGY. Provider authentication, Pi's `auth.json`, saved project trust, and AGY's trusted-workspace list are machine-local and are **not** copied from this repository.

For Jev, use one protected TypeSafe key file shared by both tools. Create it once at `~/.config/typesafe/jev_api_key` with owner-only permissions. For example, in an interactive Bash shell:

```bash
install -d -m 700 "$HOME/.config/typesafe"
read -rsp 'TypeSafe API key: ' TYPESAFE_KEY
printf '\n'
(umask 077; printf '%s\n' "$TYPESAFE_KEY" > "$HOME/.config/typesafe/jev_api_key")
unset TYPESAFE_KEY
chmod 600 "$HOME/.config/typesafe/jev_api_key"
```

If the file already exists, preserve it rather than overwriting it blindly. Never put the key in the repo, a command argument, or a Git commit. Pi is linked to this file; AGY stores only the file path in MCP configuration.

### 3. Install the environment

```bash
git clone <this-repository-url> pi-sandbox
cd pi-sandbox
./install.sh --all
```

The full install merges managed settings without replacing unrelated JSON keys, installs the Pi package and files, provisions pinned skills, builds/tests the AGY MCP adapter if needed, and registers the local Jev server if it is not already registered. Existing config files are backed up before changes. Existing conflicting skill directories are preserved and cause the installer to stop rather than silently replacing them.

For an existing installation with old copies of the shared skills, explicitly request the safe migration. Original directories are moved intact outside skill-discovery paths to `~/.pi-sandbox-backups/skills/` before the common links are created:

```bash
./install.sh --all --migrate-existing
```

The AGY installer leaves an existing same-named MCP entry untouched. If you move this repo and verification reports a stale adapter path, update that entry explicitly (the key value is never an argument):

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
agy mcp add --env "TYPESAFE_API_KEY_FILE=$HOME/.config/typesafe/jev_api_key" \
  pi-sandbox-jev node "$REPO_ROOT/tools/antigravity/jev-mcp/dist/index.js"
```

If you intentionally do not want the public third-party skill repositories, use `--no-external` and later verify with the same option:

```bash
./install.sh --all --no-external
tools/install/verify.sh --no-external
```

### 4. Verify

```bash
tools/install/verify.sh
```

The verifier checks prerequisites and versions, Pi and AGY managed files/settings, automatic-Jev configuration, common and pinned skill links, the local MCP registration, and secret-file permissions. It never prints secret values and does **not** make live Jev API calls. If credentials are not configured yet, they are reported as warnings; require them with:

```bash
tools/install/verify.sh --strict-credentials
```

### 5. Start new sessions

- In an interactive Bash shell, run `source ~/.bashrc` if needed, then start `pi`. `/jev status` should show automatic routing enabled. Pi's `PI_JEV_AUTO=1` enables a Jev tool/skill routing request per prompt; it requires a configured key and incurs a Jev request per prompt.
- Start a new `agy` session after installation. The Jev plugin supplies the global development rule, session-start and first-invocation reminders, the Jev skill, and permissions for the named `jev_evaluate` and `jev_gate` tools. For software-development tasks the rule instructs AGY to evaluate plans with Jev. AGY automation is instruction-and-hook based, not a hard guarantee that every kind of task will call Jev. A live synthetic Jev smoke test is described in [`doc/spec/antigravity.md`](doc/spec/antigravity.md).

## Installer commands

```bash
./install.sh                         # legacy behavior: install pi-snap only
./install.sh --all                   # install all repo-managed components
./install.sh --all --dry-run         # preview changes without writing
./install.sh --all --check           # report drift without writing
./install.sh --all --no-external     # omit pinned third-party skills
./install.sh --all --migrate-existing # preserve old skill dirs, then link common sources

tools/install/install-pi.sh [--dry-run|--check]
tools/install/install-agy.sh [--dry-run|--check|--build]
tools/install/install-skills.sh [--dry-run|--check|--no-external|--migrate-existing]
tools/install/verify.sh [--no-external] [--strict-credentials]
```

`./install.sh` with no arguments remains compatible with the original Pi-snap installer. Component installers are also available directly.

## What is managed

| Component | Repo source | Installed location |
|---|---|---|
| Pi global settings | `config/pi/settings.template.json` | `~/.pi/agent/settings.json` (managed keys only; packages are additive) |
| Pi project default model | `.pi/settings.json` | loaded for this repo after project trust |
| Pi instructions and keybindings | `config/pi/AGENT.md`, `config/pi/keybindings.json` | `~/.pi/agent/` |
| Pi extensions | `config/pi/extensions/`, `tools/popular-models/` | `~/.pi/agent/extensions/` |
| Shared skills | `skills/common/` | Pi `~/.pi/agent/skills/`, AGY `~/.gemini/config/skills/` |
| Pi Jev package | `npm:pi-jev` in settings; installed by `pi install` | `~/.pi/agent/npm/` |
| Automatic Pi Jev | `config/pi/shell/jev-auto.sh` | managed block in `~/.bashrc` |
| AGY CLI settings/keybindings | `config/agy/*.template.json` | `~/.gemini/antigravity-cli/` |
| AGY Jev plugin | `config/agy/plugin/pi-sandbox-jev/` | `~/.gemini/config/plugins/pi-sandbox-jev` |
| AGY MCP adapter | `tools/antigravity/jev-mcp/` | local stdio MCP registration `pi-sandbox-jev` |
| Third-party skills | `tools/skills.lock` | pinned clones and skill links in Pi/AGY |
| Rollback helper | `tools/pi-snap` | `~/.pi/agent/bin/pi-snap` |

See [`config/manifest.tsv`](config/manifest.tsv) for the complete source/target/mode inventory.

## State intentionally kept outside the repository

The installers never copy or commit provider credentials, TypeSafe keys, Pi auth, project trust decisions, AGY trusted workspaces, conversation history, or machine-specific model/permission choices. AGY's `editor`, color scheme, notifications, status line, keybindings, plugin enablement, and narrow named Jev MCP allow rules are managed; its model, deny rules, workspace trust, and other user permissions are preserved.

External skills are pinned by commit. By default they are cloned under `~/Code/3party`; set `PI_SANDBOX_SKILLS_ROOT` to choose another parent directory. The `fd` binary present on the original machine is not vendored by this repo; install `fd-find` (or an equivalent `fd`) separately if you want that optional helper.

## `pi-snap` rollback helper

Snapshots live under `~/.pi/snapshots/`, keep the latest 10 per project by default, and use hardlinks for unchanged files. Regenerable directories such as `.git`, `node_modules`, `build`, and `dist` are excluded.

```bash
cd ~/Code/myproject
pi-snap                 # checkpoint
pi-snap list
pi-snap diff latest
pi-snap restore latest  # current state is snapshotted first
```

`PI_SNAP_ROOT` changes the store location; `PI_SNAP_KEEP` changes retention. Run `pi-snap help` for the complete command list.

## Tests and documentation

```bash
bash tools/install/test.sh
bash tools/install/test-skills.sh
bash tools/install/test-e2e.sh
cd tools/antigravity/jev-mcp
npm run typecheck && npm test && npm run build
```

Run `test-e2e.sh` after the adapter is built; the normal `./install.sh --all` does this on a clean clone. The end-to-end test uses CLI shims and does not contact TypeSafe.

- [Bootstrap/install specification](doc/spec/bootstrap.md)
- [Pi and AGY spec index](doc/spec/README.md)
- [Sandbox design record](doc/plan/archive/pi-sandbox-daily-tier-plan.md)
