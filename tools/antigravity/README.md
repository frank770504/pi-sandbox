# Antigravity (AGY) Jev workflow

This folder contains the repo-managed Antigravity CLI integration for the Pi/Jev
workflow discussed in `doc/spec/antigravity.md`:

- `jev-mcp/` — local stdio MCP adapter using the official TypeSafe SDK.
- `skills/jev-development/SKILL.md` — reusable AGY development-flow skill.
- `global-rule-addendum.md` — managed section appended to `~/.gemini/GEMINI.md`.
- `install-agy.sh` — build/test the adapter, install the skill, register the MCP
  server, and merge the managed rule section without replacing unrelated rules.

## Install

```bash
bash tools/antigravity/install-agy.sh
agy mcp list
```

The script runs the adapter tests and build before changing AGY configuration.
It creates a timestamped backup before updating `~/.gemini/GEMINI.md`, refuses
an existing different skill file, and leaves an already registered MCP server
with the same name untouched.

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
