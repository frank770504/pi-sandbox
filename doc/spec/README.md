# Pi Custom Configuration — Spec Index

Machine: local development machine (Ubuntu 22.04, x86_64)
Updated: 2025-09-07

This directory documents **all custom pi configuration on this machine** — the
delta from pi's stock defaults. Secrets are redacted; structure is recorded.

## Layout of pi config

| Spec | Covers | Source |
|---|---|---|
| [settings.md](settings.md) | Global settings, providers, project trust | `~/.pi/agent/settings.json`, `auth.json`, `trust.json` |
| [keybindings.md](keybindings.md) | TUI editor/input keybindings | `~/.pi/agent/keybindings.json` |
| [agent-instructions.md](agent-instructions.md) | Global system prompt | `~/.pi/agent/AGENT.md` |
| [extensions.md](extensions.md) | Custom extensions | `~/.pi/agent/extensions/*.ts` |
| [skills.md](skills.md) | Installed skills | `~/.pi/agent/skills/` |
| [bin-and-shell.md](bin-and-shell.md) | Helper scripts & shell alias | `~/.pi/agent/bin/`, `~/.bashrc` |

## Related design doc

- Sandbox (daily-tier safety net): `doc/plan/archive/pi-sandbox-daily-tier-plan.md`

## Customization summary (delta from stock)

1. **Provider/model**: OpenRouter (`deepseek/deepseek-v4-pro-0813`), plus Google.
2. **Thinking level**: `high`.
3. **Project trust**: explicit `ask` (default, but pinned).
4. **Global system prompt** (`AGENT.md`): 3-step Align→Plan→Wait approval flow + delete-permission rule.
5. **Extensions**: `delete-guard` (destructive-op guard) + `session-snapshot` (rollback snapshots).
6. **Keybindings**: vim-style cursor + `alt+enter` newline.
7. **Skills**: catch-up-project, code-review, grill-me, science-skills-common, uv.
8. **Helpers**: `pi-snap` hardlink snapshot script + `pi-snap` shell alias + `fd` binary.
