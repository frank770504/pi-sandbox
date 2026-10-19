#!/bin/sh
# PreInvocation hook: on the first model call of a session, inject an ephemeral
# reminder to use the Jev planning evaluation. Later invocations stay silent.
payload=$(cat)
num=$(printf '%s' "$payload" | python3 -c 'import json,sys
try:
    data = json.load(sys.stdin)
except Exception:
    print(0)
else:
    print(data.get("invocationNum", 0))' 2>/dev/null)

if [ "$num" = "1" ]; then
  printf '%s\n' '{"injectSteps":[{"ephemeralMessage":"Before the plan in this turn: for software-development tasks, read the jev-development skill and call jev_evaluate once with a minimized, non-sensitive summary."}]}'
else
  printf '%s\n' '{"injectSteps":[]}'
fi
