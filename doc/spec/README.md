# Pi Custom Configuration — Spec Index

Machine: local development machine (Ubuntu 22.04, x86_64)
Updated: 2025-09-07

This directory documents **all custom pi configuration on this machine** — the
delta from pi's stock defaults. Secrets are redacted; structure is recorded.

## Layout of pi config

| Spec | Covers | Source |
|---|---|---|
| [settings.md](settings.md) | Global settings, providers, project trust, pi-jev package and setup | `~/.pi/agent/settings.json`, `auth.json`, `trust.json` |
| [keybindings.md](keybindings.md) | TUI editor/input keybindings | `~/.pi/agent/keybindings.json` |
| [agent-instructions.md](agent-instructions.md) | Global system prompt | `~/.pi/agent/AGENT.md` |
| [extensions.md](extensions.md) | Custom extensions | `~/.pi/agent/extensions/*.ts` |
| [skills.md](skills.md) | Installed skills | `~/.pi/agent/skills/` |
| [bin-and-shell.md](bin-and-shell.md) | Helper scripts & shell alias | `tools/pi-snap`, `install.sh`, `~/.pi/agent/bin/`, `~/.bashrc` |

## Related design doc

- Sandbox (daily-tier safety net): `doc/plan/archive/pi-sandbox-daily-tier-plan.md`

## Customization summary (delta from stock)

1. **Provider/model**: OpenRouter (`deepseek/deepseek-v4-pro-0813`), plus Google.
2. **Thinking level**: `high`.
3. **Project trust**: explicit `ask` (default, but pinned).
4. **Global system prompt** (`AGENT.md`): 3-step Align→Plan→Wait approval flow, pi-jev bug-fix pilot, and delete-permission rule.
5. **Pi package**: `npm:pi-jev`, configured for manual typed evaluation and advisory gate checks; TypeSafe API key is kept outside the repo.
6. **Extensions**: `delete-guard` (destructive-op guard) + `session-snapshot` (rollback snapshots).
7. **Keybindings**: vim-style cursor + `alt+enter` newline.
8. **Skills**: catch-up-project, code-review, grill-me, science-skills-common, uv.
9. **Helpers**: `pi-snap` snapshot/management CLI (repo `tools/pi-snap`, deployed by `install.sh`) + `pi-snap` shell alias + `fd` binary.
