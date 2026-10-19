# Jev-Assisted Development (Antigravity)

For software-development tasks, read the `jev-development` skill before
presenting an implementation plan, and use the `jev_evaluate` MCP tool once per
planning round before asking for approval.

- Before approval, inspect the repository locally with read-only operations and
  send Jev only a minimized, non-sensitive task summary, explicit constraints,
  generalized verified repo findings, and the proposed plan.
- Never send raw source, diffs, private identifiers or paths, logs, credentials,
  personal or customer data, proprietary details, or vulnerabilities without the
  user's explicit permission. If sharing safety is uncertain, omit the detail or
  skip the Jev call.
- Follow the fixed 0–4 rubric, the 10-evaluation cap per planning run, the
  refinement and stop rules, and the reporting requirements in the skill.
- Jev scores are advisory. They do not override the user's approval authority
  and never authorize deleting or overwriting files without explicit permission.
- Do not edit files or run tests, builds, installations, or mutating commands
  until the user explicitly says "Go ahead" or "Approved."
- After approval, stay within the approved plan. Run deterministic tests before
  any advisory Jev gate. If Jev is unavailable or the state cannot be safely
  shared, report that instead of fabricating a score or a gate result.
