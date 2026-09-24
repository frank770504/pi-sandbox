# Pi and Antigravity Custom Configuration — Spec Index

Machine: local development machine (Ubuntu 22.04, x86_64)
Updated: 2026-09-23

This directory documents custom Pi and Antigravity configuration on this
machine. Secrets are redacted; structure is recorded.

## Layout of pi config

| Spec | Covers | Source |
|---|---|---|
| [settings.md](settings.md) | Global settings, providers, project trust, pi-jev package and setup | `~/.pi/agent/settings.json`, `auth.json`, `trust.json` |
| [keybindings.md](keybindings.md) | TUI editor/input keybindings | `~/.pi/agent/keybindings.json` |
| [agent-instructions.md](agent-instructions.md) | Global system prompt | `~/.pi/agent/AGENT.md` |
| [extensions.md](extensions.md) | Custom extensions | `~/.pi/agent/extensions/*.ts` |
| [skills.md](skills.md) | Installed skills | `~/.pi/agent/skills/` |
| [bin-and-shell.md](bin-and-shell.md) | Helper scripts & shell alias | `tools/pi-snap`, `install.sh`, `~/.pi/agent/bin/`, `~/.bashrc` |
| [antigravity.md](antigravity.md) | AGY global instructions, skill, TypeSafe MCP integration | `tools/antigravity/`, `~/.gemini/GEMINI.md`, `~/.gemini/config/skills/`, AGY MCP settings |

## Related design doc

- Sandbox (daily-tier safety net): `doc/plan/archive/pi-sandbox-daily-tier-plan.md`

## Customization summary (delta from stock)

1. **Provider/model**: OpenRouter (`deepseek/deepseek-v4-pro-0813`), plus Google.
2. **Thinking level**: `high`.
3. **Project trust**: explicit `ask` (default, but pinned).
4. **Global system prompt** (`AGENT.md`): Align→Plan→Wait with read-only repo inspection and bounded pre-approval pi-jev planning scores, plus post-approval checks and delete rules.
5. **Pi package**: `npm:pi-jev`, configured for privacy-filtered typed evaluations, conditional discovery, and advisory gate checks; TypeSafe API key is kept outside the repo.
6. **Extensions**: `delete-guard` (destructive-op guard) + `session-snapshot` (rollback snapshots).
7. **Keybindings**: vim-style cursor + `alt+enter` newline.
8. **Skills**: catch-up-project, code-review, grill-me, science-skills-common, uv.
9. **Helpers**: `pi-snap` snapshot/management CLI (repo `tools/pi-snap`, deployed by `install.sh`) + `pi-snap` shell alias + `fd` binary.
10. **Antigravity CLI**: repo-managed Jev development skill and local TypeSafe MCP adapter, installed by `tools/antigravity/install-agy.sh`.
