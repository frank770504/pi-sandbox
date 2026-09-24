---
name: jev-development
description: >-
  Use for software-development tasks in Antigravity that follow the Pi/Jev
  workflow: repo-aware planning, pre-approval TypeSafe Jev alignment scoring,
  explicit user approval, and post-change tests plus an advisory Jev gate.
---

# Jev-Assisted Development Workflow

This skill implements the repo-aware planning and validation workflow for AGY.
The global `GEMINI.md` rule retains the user's approval authority. A Jev score is
advisory and never grants permission to edit or run tests.

## Before approval: inspect, score, refine

1. Inspect the repository locally using read-only file reads, listing/search,
   `git status`, and `git diff`. Do not edit files or run tests, builds,
   installations, or mutating commands before explicit approval.
2. Draft a task understanding and implementation plan grounded in verified
   repository findings. Send the AGY MCP tool `jev_evaluate` only a minimized,
   non-sensitive task summary, explicit constraints, generalized verified repo
   findings, and the current plan.
3. Never send raw source, diffs, private identifiers/paths, logs, credentials,
   personal/customer data, proprietary details, or vulnerabilities without the
   user's explicit permission. If unsure, omit the detail or skip the Jev call.
4. Use one fixed `jev_evaluate` request per planning round. Ask for an overall
   score plus diagnostic scores for intent coverage, scope/constraints, repo fit,
   assumptions, and validation fit, and a `primary_gap` choice. Use the same
   ordered rubric on every round:
   - 0: materially misaligned or violates an important constraint;
   - 1: major omission, scope mismatch, or unsupported assumption;
   - 2: a meaningful gap remains;
   - 3: strong alignment with only minor non-blocking gaps;
   - 4: fully aligned, repo-grounded, and validated in the plan.

   Jev's score is an expected value on this native 0–4 scale and may be
   fractional. Display confidence separately. Do not set a numeric approval
   threshold or treat confidence as permission.
5. Keep the original request, constraints, and rubric fixed while revising only
   the plan and adding only locally verified repo facts. The hard limit is 10
   Jev evaluations per planning run, including the first and user-requested
   revisions. Stop early when no material gap remains or after two rounds
   without meaningful progress. If a material gap remains at the limit, ask the
   user to clarify instead of requesting approval.
6. Before asking for approval, show the polished plan, score progression, final
   dimension scores, confidence, iteration count, assumptions, and unresolved
   concerns. Do not show unpolished drafts by default. The user decides whether
   to say “Go ahead.” A material task change starts a new planning run.

If `jev_evaluate` is unavailable or the request cannot be safely summarized,
show the plan without a score and say why. Never fabricate an evaluation.

## After approval: implement within scope

1. Use AGY's native skills/tools selectively after approval. Do not recreate
   Pi-specific `jev_find_skill` or `jev_find_tools` unless a concrete need arises.
2. Implement only within the approved plan. If new findings require material
   scope expansion, stop and ask for renewed approval.
3. Run deterministic project tests. Allow at most two in-scope fix-and-rerun
   attempts; if failures remain or need broader scope, stop and report. A Jev
   gate never overrides failing tests.
4. The gate criterion must be explicit in the approved plan before coding. Only
   call `jev_gate` after tests pass and when the supplied diff/state is safe to
   share with TypeSafe or the user explicitly authorizes it. Before using the
   gate, confirm the working tree was clean at task start and a fresh local
   review shows only approved task changes. `jev_gate` receives only the
   caller-supplied state; it must not read files or run Git commands.
5. The gate is advisory, with a default 0.70 probability threshold. If it
   rejects, inspect the concern; make at most one in-scope correction, then
   rerun tests and the gate. Stop for approval if the fix expands scope.
6. If Jev is unavailable, report the score/gate as unavailable; do not invent a
   result. Normal human-approved work and deterministic tests may continue.

## Feature boundaries and final report

- Keep `/jev auto`, agent orchestration, tool-guard, and auto-model automation
  off. Use the fixed `jev_evaluate` rubric instead of a dynamic evaluation
  prompt.
- Jev compaction is optional and manual, only for sessions whose history is
  safe to send to TypeSafe.
- Apply data-minimization and consent rules to every TypeSafe call.
- Report plan-alignment scores, gate probability/criterion, test outcomes, and
  any skipped check as separate signals. Never merge them into one quality score.
