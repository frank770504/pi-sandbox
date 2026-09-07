# Spec — Skills

Source: `~/.pi/agent/skills/`

| Dir | Skill name | Kind | Description |
|---|---|---|---|
| `catch-up-project/` | `catch-up-project` | local | Catch up on a project: architecture, rules, feature specs. Use on new session or "catch up". |
| `code-review-skill/` → `~/Code/3party/code-review-skill` | `code-review-excellence` | symlink | Comprehensive code review guidance (React/Vue/Angular/Svelte, Rust, TS, Python, Go, Java, C/C++…). Use for PR review, bug-hunting, review standards. |
| `grill-me/` | `grill-me` | local | Relentlessly interview about a plan/design until shared understanding. Use for "grill me" / stress-testing a plan. |
| `science_skills_common/` → `~/Code/3party/science-skills/skills/science_skills_common/` | `science-skills-common` | symlink | Shared Python package (`http_client`). Not a standalone skill. |
| `uv/` → `~/Code/3party/science-skills/skills/uv/` | `uv` | symlink | Ensures `uv` is installed and on PATH; prerequisite for other science skills. |

### Notes

- Local skills (`catch-up-project`, `grill-me`) live in the agent home and are
  self-contained.
- Symlinked skills point into `~/Code/3party/` — moving that tree breaks them;
  re-link with `ln -s <target> ~/.pi/agent/skills/<name>` if relocated.
