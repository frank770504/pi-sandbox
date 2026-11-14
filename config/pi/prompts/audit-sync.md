---
description: Audit repo-vs-machine drift and plan the update (never writes)
---
Audit how far this computer has drifted from the pi-sandbox repository, then
produce an update plan. **Read-only: do not modify, install, or write anything.**
Execution happens only when I explicitly ask afterwards.

## Steps

1. **Drift check.** Run without writing:
   - `./install.sh --all --check`
   - `bash tools/install/install-pi.sh --check`
   - `bash tools/install/install-agy.sh --check`
   - `bash tools/install/install-skills.sh --check`
   - `bash tools/install/verify.sh`
2. **Diff analysis.** For every item reported out of date or failing, show the
   actual difference between the repo source and the installed target
   (`diff`, read-only). State clearly which side is newer and why.
3. **Platform-safety audit.** For every pending change, check portability
   between Ubuntu/Linux and macOS: GNU-only flags (`find -printf`, `sed -i`,
   `mapfile`, `date +%N`), BSD-only flags, hardcoded paths, and shell
   differences. Flag anything that would work on one OS but not the other.
4. **Report.** Present:
   - a discrepancy table (item, installed state, repo state, verdict);
   - an ordered update plan with the exact commands, noting that the
     installers back up each existing file to `<target>.bak.<timestamp>`
     before writing and that JSON merges are additive;
   - any policy tradeoffs that need my decision before executing.
5. **Score.** Run `jev_evaluate` on the plan with a 0–4 alignment rubric
   (0 = wrong/unsafe, 100-scale intent: 25 = major gaps, 50 = significant
   gaps, 75 = solid with minor open items, 100 = fully aligned, verified
   safe). Show the score. If it is below 3.5/4, ask me targeted clarifying
   questions and re-score before finalizing the plan.
6. **Stop.** End with the plan and the score. Do not run `install.sh`
   without `--check`, do not edit files outside the repo, and do not commit.

$ARGUMENTS
