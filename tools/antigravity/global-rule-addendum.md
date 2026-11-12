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

## Tool Call & Secret Hygiene
- Never pass literal API keys, tokens, passwords, `.env` values, real email addresses, or realistic phone numbers inside `write`, `edit`, or `bash` tool call arguments.
- Reference environment variables (e.g., `$OPENROUTER_API_KEY`) in shell commands and scripts instead of hardcoding secrets.
- For test fixtures or mock data, use obvious non-PII placeholders (`000-0000`, `[EMAIL]`, `sk-placeholder`).

<!-- END pi-sandbox Jev-assisted development workflow -->
