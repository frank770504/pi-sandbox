# Antigravity (AGY) Jev workflow

This folder contains the TypeSafe Jev stdio MCP adapter and legacy install assets. The current full environment setup is managed from `config/agy/` and `tools/install/install-agy.sh`; see [`doc/spec/antigravity.md`](../../doc/spec/antigravity.md).

- `jev-mcp/` — local stdio MCP adapter using the official TypeSafe SDK.
- `skills/jev-development/SKILL.md` — legacy standalone skill source; the active plugin source is under `config/agy/plugin/pi-sandbox-jev/`.
- `AGY_RULE.md`, `global-rule-addendum.md`, and `install-agy.sh` — retained for compatibility with the earlier GEMINI.md-based installation.

## Install

For a complete Pi + AGY setup, use the repository root orchestrator:

```bash
./install.sh --all
agy mcp list
tools/install/verify.sh
```

For AGY-only setup, run `bash tools/install/install-agy.sh`. The older
`bash tools/antigravity/install-agy.sh` is retained for compatibility with the
previous GEMINI.md workflow; it does not install the current AGY keybindings,
managed editor settings, shared skills, plugin enablement, or hooks.

## TypeSafe credentials

The MCP server accepts `TYPESAFE_API_KEY` from the environment, or an explicit
`TYPESAFE_API_KEY_FILE` pointing to a regular file readable only by its owner
(mode `0600` or stricter). The secret value is never written to AGY's MCP config,
command arguments, repository files, or logs. The process fails closed if no
safe credential is available.

Launch `agy` from a shell that has `TYPESAFE_API_KEY` configured. For a key
file, set `TYPESAFE_API_KEY_FILE` to its protected path before running the
installer; it stores only that path in the MCP config. Do not put the key value
in `agy mcp add --env`. If the MCP is already registered, the installer leaves
it unchanged; update it explicitly with `agy mcp add --env TYPESAFE_API_KEY_FILE=/path/to/owner-only-file pi-sandbox-jev node <server-entry>` after creating a safe key file.

The adapter's `jev_gate` tool accepts state/diff explicitly and does not read
repository files or invoke Git. All content passed to either MCP tool is sent
to TypeSafe, so follow the workflow's data-minimization and consent rules.
