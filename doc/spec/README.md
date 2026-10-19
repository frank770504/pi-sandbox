# Pi and Antigravity Configuration — Spec Index

Updated: 2026-10-19

This repo describes and installs repo-managed Pi and Antigravity configuration. Secrets, auth state, trust decisions, user-specific model settings, and workspace lists remain outside the repo.

## Specs

| Spec | Covers | Canonical source / target |
|---|---|---|
| [bootstrap.md](bootstrap.md) | Prerequisites, clean setup, verification, secrets, trust, migrations | `README.md`, `install.sh`, `tools/install/` |
| [settings.md](settings.md) | Pi defaults, trust, provider auth boundary, automatic Jev | `config/pi/settings.template.json`, `.pi/settings.json`, `~/.pi/agent/settings.json` |
| [agent-instructions.md](agent-instructions.md) | Global Pi instructions and workflow | `config/pi/AGENT.md` → `~/.pi/agent/AGENT.md` |
| [keybindings.md](keybindings.md) | Pi terminal bindings | `config/pi/keybindings.json` → `~/.pi/agent/keybindings.json` |
| [extensions.md](extensions.md) | Pi extensions and snapshot behavior | `config/pi/extensions/`, `tools/popular-models/` |
| [skills.md](skills.md) | Shared, Pi-only, AGY-only, and pinned external skills | `skills/`, `tools/skills.lock` |
| [bin-and-shell.md](bin-and-shell.md) | Pi-snap, shell blocks, installers, verifier | `tools/pi-snap`, `config/pi/shell/`, `tools/install/` |
| [antigravity.md](antigravity.md) | AGY settings, keybindings, plugin, hooks, MCP, Jev behavior | `config/agy/`, `tools/antigravity/` |

## Customization summary

1. Pi defaults are OpenRouter `cohere/north-mini-code:free`, high thinking, ask trust, dark theme, and `npm:pi-jev`.
2. Pi automatic Jev tool/skill routing is enabled by `PI_JEV_AUTO=1`; other automatic Jev modes remain off.
3. Pi has a destructive-operation guard, automatic session snapshot, and popular-models transcript widget.
4. AGY uses Vim editor mode, managed keybindings, an always-on Jev plugin rule, session hooks, and the local `pi-sandbox-jev` MCP adapter.
5. `skills/common/` is the single source for the shared catch-up and grill-me skills, linked into Pi and AGY. Third-party skill repos are pinned in `tools/skills.lock`.
6. `pi-snap` provides a manual and session-start rollback safety net. This is not process isolation.

## Related design doc

- [Pi daily-tier sandbox plan](../plan/archive/pi-sandbox-daily-tier-plan.md)
