# Spec — Global Settings, Providers, Project Trust

## 1. `~/.pi/agent/settings.json`

```json
{
  "lastChangelogVersion": "0.85.1",
  "defaultProvider": "openrouter",
  "defaultModel": "deepseek/deepseek-v4-pro-0813",
  "defaultThinkingLevel": "high",
  "defaultProjectTrust": "ask",
  "packages": ["npm:pi-jev"]
}
```

| Field | Value | Meaning |
|---|---|---|
| `lastChangelogVersion` | `0.85.1` | Tracks last-shown changelog version (pi-managed, not user-set). |
| `defaultProvider` | `openrouter` | Default model provider for new sessions. |
| `defaultModel` | `deepseek/deepseek-v4-pro-0813` | Default model. |
| `defaultThinkingLevel` | `high` | Default thinking/effort level. |
| `defaultProjectTrust` | `ask` | Input-loading guard: prompt once per new project before loading `.pi`/`.agents` resources. |
| `packages` | `["npm:pi-jev"]` | Loads pi-jev's tools and commands in Pi sessions. |

### Project trust semantics

- `defaultProjectTrust: "ask"` is the stock default; pinned explicitly here for
  clarity.
- Saved decisions live in `~/.pi/agent/trust.json` (per canonical directory), so
  each project prompts **once** and is remembered thereafter.
- Non-interactive modes (`-p`, `--mode json`, `--mode rpc`) never prompt; with
  `ask` they **ignore** trust-requiring resources unless a saved decision exists.
  Override per-run with `-a`/`--approve` or `-na`/`--no-approve`.
- Trust is **not** a sandbox — it only guards loading of project-local settings,
  extensions, skills, prompts, themes, and system-prompt files.

## pi-jev package and credentials

The `packages` setting installs/loads `npm:pi-jev`, which provides semantic tool
and skill discovery, typed evaluations, and the `pi-jev-gate` CLI. To add it on
a new machine, install the package with `pi install npm:pi-jev` or add it to the
`packages` array in `~/.pi/agent/settings.json`.

Jev requests require a TypeSafe API key. Provide it through `TYPESAFE_API_KEY`
or store it in `~/.pi/agent/secrets/typesafe_api_key`. **Never commit the key
into this repository.** Verify setup in Pi with `/jev status`.

## Jev-assisted development flow (pilot)

The agent may inspect the repository locally using read-only operations before
asking for approval. The same data-minimization and consent rules apply to all
TypeSafe requests, including discovery, evaluation, gating, and compaction. It
sends Jev only a minimized, non-sensitive task summary,
explicit constraints, generalized verified repo findings, and the current plan.
Raw source, diffs, private identifiers/paths, logs, credentials, personal or
customer data, proprietary details, and vulnerabilities are not sent without
explicit permission. If safety is uncertain, omit the detail or skip Jev.

Before approval, the agent uses one `jev_evaluate` request per planning round.
The fixed rubric has ordered anchors from 0 to 4, and Jev returns an expected
score that may be fractional, plus confidence. Questions cover overall
alignment, intent coverage, scope/constraints, repo fit, assumptions, validation
fit, and the primary gap. The task, constraints, and rubric stay fixed while the
plan is revised. The maximum is 10 evaluation requests per planning run,
including user-requested revisions; stop earlier for no material gap or after
two rounds without meaningful progress. There is no numeric approval threshold:
the agent presents the polished plan, score progression, final scores,
confidence, and caveats, then waits for the user's decision.

After approval, `jev_find_skill` is used for specialized work and
`jev_find_tools` only if an available capability is missing. Both are
conditional; `/jev auto` remains off. Deterministic tests run before any Jev
gate. The gate criterion comes from the approved plan and is not revised after
seeing the diff. `pi-jev-gate --diff` is advisory and runs only after tests pass,
with a clean working tree at task start, a fresh local review confirming the
current diff contains only approved task changes, and only when sharing the diff
with TypeSafe is allowed or explicitly authorized. The command evaluates
tracked changes against `HEAD` and omits untracked files. A rejected gate allows at most
one in-scope correction followed by tests and a rerun; it never overrides test
failures. Allow at most two in-scope test-fix attempts. If Jev is unavailable,
report the missing score/gate and continue with ordinary human-approved work.

`/jev agents`, `/jev auto-agents`, `/jev tool-guard`, and `/jev auto-model` stay
off for this pilot. `/jev test` is for ad hoc exploration, not the fixed loop.
Jev compaction is an optional manual choice per session (`/jev compact on`, then
`/compact`) and is used only when that session's history is safe to send to
TypeSafe. Keep planning scores, gate probability, and test results separate in
reports. Automatic-mode preferences are session/runtime choices; no automatic
mode is enabled by this settings configuration.

## 2. `~/.pi/agent/auth.json` (structure only — values redacted)

```json
{
  "google":    { "type": "...", "key": "..." },
  "openrouter": { "type": "...", "key": "..." }
}
```

| Provider | Purpose |
|---|---|
| `openrouter` | Default provider (see `settings.json`). |
| `google` | Secondary provider (Gemini-family models). |

Security: keys live on the host under the user account. Per the sandbox plan,
they remain here for the trusted daily tier; the untrusted Docker tier will use
a separate scoped key and never mount this file.

## 3. `~/.pi/agent/trust.json`

Currently absent/empty — no saved project-trust decisions yet. First trust
prompt in each project will populate it.
