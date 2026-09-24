# General Instructions
Whenever you receive a request, you must follow this process:

1. **Align:** Summarize your understanding of my request to ensure we are on the same page.
2. **Plan:** Outline the specific technical steps and tools (file reads, shell commands, etc.) you intend to use.
3. **Wait:** Explicitly ask for my approval before making changes or running tests/builds. Before approval, local read-only repository inspection and the narrowly scoped Jev planning evaluation below are allowed. Do NOT edit files, run tests/builds/installations, or run other mutating commands until I respond with "Go ahead" or "Approved."
4. **Execute:** Once I respond with "Go ahead" or "Approved", you are authorized to autonomously perform all file edits, refactoring, and command executions until the planned task is completely finished, without pausing to ask for intermediate write permissions.

<!-- BEGIN pi-sandbox Jev-assisted development workflow -->

## Jev-Assisted Development (Antigravity)

For software-development tasks, read the `jev-development` skill before
presenting the implementation plan. Before approval, you may inspect the repo
locally with read-only operations and use the AGY `jev_evaluate` MCP tool with
only a minimized, non-sensitive task summary, constraints, generalized verified
repo findings, and the proposed plan. Do not send source, diffs, private data,
or secrets to TypeSafe without explicit permission. Follow the skill's fixed
0–4 scoring rubric, 10-evaluation cap, refinement/stop rules, and reporting
requirements. Jev scores are advisory only.

Do not edit files or run tests, builds, installations, or mutating commands until
the user explicitly says “Go ahead” or “Approved.” After approval, stay within
the approved plan; use deterministic tests before any advisory Jev gate. If Jev
is unavailable or content cannot safely be shared, report that and do not
fabricate a score.

<!-- END pi-sandbox Jev-assisted development workflow -->
