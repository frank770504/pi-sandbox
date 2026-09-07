# Spec — Global Settings, Providers, Project Trust

## 1. `~/.pi/agent/settings.json`

```json
{
  "lastChangelogVersion": "0.85.1",
  "defaultProvider": "openrouter",
  "defaultModel": "deepseek/deepseek-v4-pro-0813",
  "defaultThinkingLevel": "high",
  "defaultProjectTrust": "ask"
}
```

| Field | Value | Meaning |
|---|---|---|
| `lastChangelogVersion` | `0.85.1` | Tracks last-shown changelog version (pi-managed, not user-set). |
| `defaultProvider` | `openrouter` | Default model provider for new sessions. |
| `defaultModel` | `deepseek/deepseek-v4-pro-0813` | Default model. |
| `defaultThinkingLevel` | `high` | Default thinking/effort level. |
| `defaultProjectTrust` | `ask` | Input-loading guard: prompt once per new project before loading `.pi`/`.agents` resources. |

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
