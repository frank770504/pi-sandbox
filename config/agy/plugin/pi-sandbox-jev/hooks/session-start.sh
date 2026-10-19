#!/bin/sh
# SessionStart hook: inject a persistent reminder of the Jev development workflow.
printf '%s\n' '{"injectSteps":[{"systemMessage":{"systemMessage":"Jev workflow active: for software-development tasks, read the jev-development skill and run a pre-planning jev_evaluate call before presenting a plan or asking for approval. Send Jev only minimized, non-sensitive state."}}]}'
