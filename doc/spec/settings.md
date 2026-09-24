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

The development pilot uses Jev manually: `jev_evaluate` for a bounded
pre-coding risk/validation assessment, and
`npx pi-jev-gate -c '<acceptance criterion>' --diff` for an advisory post-change
diff check. Automatic modes are not enabled by this configuration.

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
