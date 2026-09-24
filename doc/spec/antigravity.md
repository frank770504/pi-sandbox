# Spec — Antigravity CLI (AGY) Jev Workflow

This spec records the AGY integration for reproducing the Pi/Jev development
workflow on this machine. The integration is intentionally local and keeps the
TypeSafe API key outside the repository and AGY configuration.

## Environment discovered

- CLI: `agy` 1.2.7 (`~/.local/bin/agy`).
- Global instructions: `~/.gemini/GEMINI.md`.
- Global skills: `~/.gemini/config/skills/<name>/SKILL.md` (per the installed
  AGY customization guide).
- The CLI supports local stdio MCP servers via `agy mcp add`.
- TypeSafe publishes an official SDK and agent skill, but no official Jev MCP
  server was found. This repo therefore contains its own small adapter using
  the official SDK; it is not an official TypeSafe MCP package.
- The workflow source is in `tools/antigravity/`; install with
  `bash tools/antigravity/install-agy.sh`.

## Files and runtime configuration

| Repo source | Installed/runtime file | Purpose |
|---|---|---|
| `tools/antigravity/AGY_RULE.md` and `global-rule-addendum.md` | `~/.gemini/GEMINI.md` | Global rule template plus managed read-only/Jev planning exception; unrelated instructions are preserved. |
| `tools/antigravity/skills/jev-development/SKILL.md` | `~/.gemini/config/skills/jev-development/SKILL.md` | Detailed score/refinement, approval, test, and gate flow. |
| `tools/antigravity/jev-mcp/` | `agy mcp` registration `pi-sandbox-jev` | Local stdio server with `jev_evaluate` and `jev_gate`. |
| `tools/antigravity/install-agy.sh` | Run manually | Builds/tests adapter and installs the AGY pieces. |

The installer refuses to overwrite a different pre-existing skill, leaves a
same-named MCP server untouched, and backs up `GEMINI.md` before changing the
managed instructions. Run a new AGY session after installation so it discovers
the skill and MCP server.

## MCP adapter

`tools/antigravity/jev-mcp/` is a pinned Node/TypeScript package using
`@typesafe-ai/sdk` and `@modelcontextprotocol/sdk`.

- `jev_evaluate` accepts explicit JSON/text state and typed `choice`, `noul`,
and `score` questions, and returns TypeSafe answers, confidence, model, and
  usage. The workflow uses the native expected score on the 0–4 rubric.
- `jev_gate` accepts explicit caller-supplied state/diff, criterion, and a
  threshold (default `0.70`); it uses a TypeSafe Noul judgment and returns
  probability/pass. It has no file-system or shell access and never collects a
  Git diff itself.
- Both tools serialize the submitted state to TypeSafe. The AGY skill restricts
  calls to minimized, non-sensitive state unless the user explicitly authorizes
  more.
- Missing credentials or service failures return an error; the adapter never
  fabricates a score or fails open.

## Credentials

Provide either:

- `TYPESAFE_API_KEY` in the environment inherited by the AGY process, or
- `TYPESAFE_API_KEY_FILE` pointing to a regular, owner-only secret file
  (permission mode `0600` or stricter on Unix).

The secret value is never passed through `agy mcp add --env`, stored in the
repository, or logged. When installing with `TYPESAFE_API_KEY_FILE` set, the
installer persists only the file path in the MCP environment. Do not reuse a
world/group-readable key file; the adapter rejects such a file. The installer
does not change key-file permissions.

## Workflow behavior

### Before approval

- Permit local read-only inspection only: file reads, listing/search, `git status`,
  and `git diff`. Do not edit, test, build, install, or run mutating commands.
- Send Jev only minimized, non-sensitive task summary, constraints, generalized
  verified repo findings, and the plan. Never send raw source/diffs, private
  identifiers/paths, logs, credentials, customer/personal data, proprietary
  details, or vulnerabilities without explicit permission.
- Use the fixed overall and diagnostic score questions (intent coverage,
  scope/constraints, repo fit, assumptions, validation fit) plus primary-gap
  choice. The ordered score anchors are 0–4; the expected score may be fractional
  and confidence is reported separately. No numeric approval threshold is used.
- Revise and reevaluate up to 10 times per planning run, including user-requested
  revisions. Stop early when no material gap remains or after two rounds without
  meaningful progress; surface unresolved material gaps instead of requesting
  approval. Present score progression, polished plan, caveats, and iteration
  count. The user's explicit “Go ahead” is still required before changes/tests.

### After approval

- Use AGY-native skill/tool discovery conditionally; keep automatic agents,
  automatic routing, tool-guard, and auto-model off.
- Stay within the approved plan; request renewed approval for material scope
  changes.
- Run deterministic tests first, with at most two in-scope fix-and-rerun
  attempts. A Jev gate cannot override failing tests.
- The acceptance criterion must be in the approved plan. Run the gate only when
  tests pass and the supplied state/diff is safe to share or explicitly
  authorized. Verify the tree was clean at task start and locally review the
  current diff; handle untracked files separately. The gate is advisory. One
  in-scope correction is allowed after a gate rejection, followed by tests and a
  gate rerun.
- Keep plan scores, gate probability/criterion, and test results distinct in the
  final report. Report skipped/unavailable checks; never invent results.

## Permission note

The discovered AGY CLI settings contain a broad `command(*)` allow rule with a
small explicit deny list. This integration does not change that permission
configuration. The approval workflow is therefore instruction-level until the
user separately chooses to review/tighten the CLI permissions.
