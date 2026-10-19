# Spec — Pi Settings, Providers, Trust, and Jev

Canonical installer source: [`config/pi/settings.template.json`](../../config/pi/settings.template.json). Install with `./install.sh --all` or `bash tools/install/install-pi.sh`. The installer merges managed keys and appends `npm:pi-jev` without dropping unrelated package entries.

## Global Pi settings

Managed settings:

```json
{
  "defaultProvider": "openrouter",
  "defaultModel": "cohere/north-mini-code:free",
  "defaultThinkingLevel": "high",
  "defaultProjectTrust": "ask",
  "theme": "dark",
  "packages": ["npm:pi-jev"]
}
```

Pi manages `lastChangelogVersion` itself; it is intentionally absent from the template. Other existing settings are preserved.

| Setting | Value | Purpose |
|---|---|---|
| `defaultProvider` | `openrouter` | Default provider for new sessions |
| `defaultModel` | `cohere/north-mini-code:free` | Default model |
| `defaultThinkingLevel` | `high` | Default reasoning level |
| `defaultProjectTrust` | `ask` | Ask before loading project-local Pi resources |
| `theme` | `dark` | Default terminal theme |
| `packages` | includes `npm:pi-jev` | Loads Jev tools and commands |

The repo also commits a project default in [`.pi/settings.json`](../../.pi/settings.json). Pi project settings load only after the project is trusted.

## Trust and provider credentials

Pi trust is an input-loading guard, **not a security sandbox**. Saved project decisions remain in `~/.pi/agent/trust.json` and are not copied from the repo. Provider credentials remain in Pi's local auth store (`~/.pi/agent/auth.json`) or are supplied through the provider's supported login/environment methods. Neither file is managed or committed here.

## Jev package and shared key

The installer runs `pi install npm:pi-jev` when the package is not physically installed. TypeSafe credentials are never stored in this repository. The documented shared key file is `~/.config/typesafe/jev_api_key`, owner-only mode `0600`; Pi links `~/.pi/agent/secrets/typesafe_api_key` to it and AGY stores only its path in MCP configuration. `tools/install/verify.sh` checks permissions without reading or printing the key.

## Automatic Pi Jev routing

The installer adds this managed block to `~/.bashrc`:

```bash
export PI_JEV_AUTO=1
```

After opening a new interactive Bash shell, Pi's pi-jev package uses Jev routing before each prompt and suggests matching skills/tools. This costs one Jev request per prompt. Set `PI_JEV_AUTO=0` in a shell to opt out for that session. Automatic model selection, automatic thinking, tool guard, agent orchestration, and Jev compaction are not enabled by this setting.

Verify interactively in Pi with `/jev status`. The command should report automatic mode on and the key origin. Jev calls fail or become inactive if the credential or network is unavailable.

## Privacy and approval workflow

The global Pi instructions are sourced from [`config/pi/AGENT.md`](../../config/pi/AGENT.md). They require repo-aware planning, privacy-minimized Jev evaluation for development planning, user approval, deterministic tests, and explicit permission for destructive operations. Automatic Jev routing sends a minimized task summary to TypeSafe; avoid including sensitive data in prompts or state sent to external services.

## Machine-local values intentionally excluded

The repository does not manage `auth.json`, `trust.json`, model catalogs, session data, provider API keys, or user-specific workspace paths. See [`bootstrap.md`](bootstrap.md) for setup and verification.
