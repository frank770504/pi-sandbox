# Spec — Antigravity CLI (AGY) Configuration and Jev

Canonical installer sources are under [`config/agy/`](../../config/agy/) and `tools/antigravity/`. Install with `./install.sh --all` or run `bash tools/install/install-agy.sh` directly.

## Managed settings and keybindings

AGY's CLI state is under `~/.gemini/antigravity-cli/`:

| Repo source | Live file | Managed values |
|---|---|---|
| `config/agy/settings.template.json` | `settings.json` | editor `vim`, dark color scheme, notifications, status line, narrow Jev MCP tool permissions |
| `config/agy/keybindings.template.json` | `keybindings.json` | multiline input, Vim insert submit, conversation item rename/delete |

JSON settings are merged. The installer preserves the existing model, trusted workspaces, deny rules, and unrelated settings. For automatic non-interactive Jev planning it adds only:

- `mcp(pi-sandbox-jev/jev_evaluate)`
- `mcp(pi-sandbox-jev/jev_gate)`

These narrow allow entries are required because AGY headless mode denies MCP calls that still require permission prompts. Existing allow and deny rules are preserved.

## Jev plugin, skills, and hooks

The repo-managed plugin is `config/agy/plugin/pi-sandbox-jev/`, linked to `~/.gemini/config/plugins/pi-sandbox-jev`. Discovery is enabled through `~/.gemini/config/plugins.json`; `~/.gemini/config/config.json` records the enabled state. It contains:

- `rules/AGENTS.md`: development planning must use the repo-aware Jev workflow and honor approval/secret rules.
- `skills/jev-development/SKILL.md`: detailed planning, validation, and advisory gate procedure.
- `hooks.json`: `SessionStart` and first-invocation `PreInvocation` reminder hooks.

Common `catch-up-project` and `grill-me` skills are linked from `skills/common/` into `~/.gemini/config/skills/`. Third-party code-review skills are pinned in [`tools/skills.lock`](../../tools/skills.lock). Existing common skill directories are preserved in `~/.pi-sandbox-backups/skills/` when explicitly migrated.

## Jev MCP adapter

The local stdio server is maintained in `tools/antigravity/jev-mcp/` and registered as `pi-sandbox-jev` in `~/.gemini/config/mcp_config.json`. It exposes `jev_evaluate` and `jev_gate`, accepts caller-supplied state only, and has no filesystem or shell access. The installer runs typecheck/tests/build when its `dist` entry is absent or `--build` is supplied. This is a repo-maintained adapter using the TypeSafe and MCP SDKs, not an official TypeSafe MCP server.

The key is not stored in MCP configuration. AGY receives `TYPESAFE_API_KEY_FILE` pointing to the owner-only `~/.config/typesafe/jev_api_key` file, or inherits `TYPESAFE_API_KEY` from its launch environment.

## Automatic Jev behavior and limitations

On a new AGY session, the `SessionStart` hook injects a persistent reminder; the first-invocation hook injects a reminder before the first model call. The enabled plugin rule and skill instruct AGY to use `jev_evaluate` before planning software-development tasks. This is instruction-and-hook based, not a native AGY automatic-MCP routing mode: a model can produce malformed tool arguments or fail to call Jev, so verify with a live synthetic development prompt when credentials are available. `tools/install/verify.sh` checks configuration without making a live Jev API request.

A verified synthetic session successfully completed a Jev evaluation after retrying malformed requests. Use a new AGY session after install so it reloads settings, skills, hooks, and MCP tools.

## User-managed AGY state

The installer does not replace the user's model, workspace trust list, permissions deny rules, OAuth credentials, session history, or unrelated global instructions. It removes only the marked repo-managed Jev block from `~/.gemini/GEMINI.md` (after backing the file up) because the plugin now owns that workflow rule. AGY login and trusted-workspace choices remain user actions.
