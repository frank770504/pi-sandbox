# AGY TypeSafe Jev MCP Adapter

A small, repo-managed **stdio MCP server** that makes TypeSafe Jev judgments
available to Antigravity CLI (`agy`). It uses the official `@typesafe-ai/sdk`
and MCP SDK. It is maintained by this repository; **it is not an official
TypeSafe MCP package**.

The server exposes only two tools. It has no repository, filesystem, or shell
access—the caller supplies the state to evaluate.

## Tools

### `jev_evaluate`

Evaluates caller-supplied text/JSON state with typed Jev questions:

- `choice`: select among named criteria;
- `noul`: estimate the probability of a yes/no condition;
- `score`: return a probability-weighted expected score over ordered criteria.

Score criteria are ordered from index 0. The AGY workflow uses five rubric anchors
(0–4), so Jev may return fractional expected scores such as `3.4`, plus confidence.
The tool returns the answers, model, and token usage. A request may contain up to
12 questions and 256 KiB of serialized input.

Example question shape:

```json
{
  "state": {
    "task_summary": "Synthetic example only",
    "plan": ["Inspect the relevant code", "Run its focused test"]
  },
  "questions": {
    "alignment": {
      "type": "score",
      "instructions": "Score how well this plan matches the task.",
      "criteria": [
        "0: materially misaligned",
        "1: major gap",
        "2: meaningful gap remains",
        "3: minor non-blocking gaps",
        "4: fully aligned"
      ]
    }
  }
}
```

### `jev_gate`

Checks whether **caller-supplied** state satisfies an acceptance criterion. It
uses a Jev Noul question and returns the probability, threshold, and `passed`
boolean. The default threshold is `0.70` (valid range `0..1`). It does not run
tests, read Git, or load a diff from disk.

## Privacy and security

Both tools send their supplied state and questions to TypeSafe. Before calling
them, follow the AGY workflow's sharing rules: send only minimized,
non-sensitive information unless the user explicitly authorizes more. In
particular, do not send source, diffs, private identifiers, logs, credentials,
customer/personal data, proprietary details, or vulnerabilities without that
authorization.

The server does not log request contents or echo invalid inputs. It fails closed
when credentials are missing, a key file is unsafe, the API request fails, or a
response is malformed; it never invents a score or passes a gate on error.

## Credentials

Use one of these sources:

1. `TYPESAFE_API_KEY` in the environment inherited by the `agy` process; or
2. `TYPESAFE_API_KEY_FILE`, pointing to a regular key file owned by the current
   user and readable only by that user (Unix mode `0600` or stricter).

The key file should contain only the raw API key on one line (commonly beginning
with `ts_`), without quotes or a `TYPESAFE_API_KEY=` prefix. Never commit the
file or put the key value in an `agy mcp add --env` argument. The adapter does
not automatically read Pi's secret file; it rejects group/world-readable key
files.

After creating a protected file at `$HOME/.config/typesafe/jev_api_key`, run
this from inside the repository to register its **path** (not its contents)
with AGY:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
agy mcp add --env "TYPESAFE_API_KEY_FILE=$HOME/.config/typesafe/jev_api_key" \
  pi-sandbox-jev node "$REPO_ROOT/tools/antigravity/jev-mcp/dist/index.js"
```

`agy mcp add` updates an existing server with the same name. This stores only
the file path in AGY's MCP configuration; the adapter checks that the file is
owned by the current user and has owner-only permissions. To use the
`TYPESAFE_API_KEY` environment-variable route instead, configure it securely in
the environment used to launch AGY.

## Install into AGY

From the root of this repository:

```bash
bash tools/antigravity/install-agy.sh
agy mcp list
```

The installer runs `npm ci`, typechecking, tests, and a build before changing
AGY configuration. It then installs the global skill, merges the managed
workflow section into `~/.gemini/GEMINI.md` while preserving unrelated text, and
registers the stdio MCP server if it is not already registered. It creates a
backup before changing `GEMINI.md`, refuses to overwrite a different existing
skill, and leaves an existing MCP registration untouched. Start a **new AGY
session** after installation to load the MCP server and skill.

If the MCP server was already installed and you later add a protected key file,
update its environment with the `agy mcp add --env ...` example above. The
installer deliberately does not overwrite an existing MCP entry.

## Develop and test

```bash
cd tools/antigravity/jev-mcp
npm ci
npm run typecheck
npm test
npm run build
```

Tests use mocked TypeSafe responses and synthetic state; they do not require an
API key. A live TypeSafe smoke test should also use synthetic, non-sensitive
state only.

## Troubleshooting

- **Server/tool not visible:** run `agy mcp list`, rebuild with `npm run build`,
  then start a new AGY session.
- **Credentials not configured:** set `TYPESAFE_API_KEY` in AGY's launch
  environment, or set `TYPESAFE_API_KEY_FILE` to an owner-only file. Do not put
  the key value in AGY's MCP config.
- **Unsafe key-file error:** the adapter checks both file ownership and Unix
  permissions. Use a file owned by the AGY user with mode `0600` or stricter.
- **Gate result differs from tests:** the gate is an advisory semantic
  judgment—not a test runner or proof of correctness. Deterministic test results
  remain authoritative.

See [the AGY workflow spec](../../../doc/spec/antigravity.md) for approval,
score-loop, and gate policies.
