# Spec — Global Pi Instructions

Canonical source: [`config/pi/AGENT.md`](../../config/pi/AGENT.md). Installed as `~/.pi/agent/AGENT.md` by `tools/install/install-pi.sh`.

The global instructions enforce:

- Align → Plan → Decide for requests, with read-only inspection before approval.
- A bounded, privacy-minimized Jev planning evaluation for software-development tasks.
- The repo's approval flow, deterministic test requirements, and advisory gate policy.
- Explicit user permission before deleting files or overwriting existing content.
- Automatic Pi Jev routing enabled through `PI_JEV_AUTO=1`; this sends a minimized routing summary once per prompt and costs one Jev request per prompt.
- Automatic Jev agents, model selection, thinking, tool guard, and compaction remain off unless explicitly chosen.

The file is the source of truth; this spec summarizes it rather than duplicating a second editable copy. Use `./install.sh --all` to install or `tools/install/install-pi.sh --check` to detect drift.
