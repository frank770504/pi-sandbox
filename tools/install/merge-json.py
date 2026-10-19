#!/usr/bin/env python3
"""Merge managed keys from a template JSON file into a target JSON file.

Managed keys are the keys present in the template. Nested objects are merged
recursively; arrays and scalars in the template replace the target value.
Unrelated target keys are preserved. A missing target is treated as empty, so
the merged output equals the template.

Usage:
  merge-json.py TEMPLATE TARGET          print merged JSON to stdout
  merge-json.py --check TEMPLATE TARGET  compare instead of printing

Exit codes:
  0  success, or (in --check mode) target already matches
  1  invalid input (unreadable or invalid JSON)
  2  usage error
  3  --check mode only: target is missing or differs
"""

import json
import sys


def merge(base, override):
    if isinstance(base, dict) and isinstance(override, dict):
        out = dict(base)
        for key, value in override.items():
            out[key] = merge(out[key], value) if key in out else value
        return out
    return override


def load(path, required):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        if required:
            print(f"merge-json: template not found: {path}", file=sys.stderr)
            sys.exit(1)
        return None
    except json.JSONDecodeError as exc:
        print(f"merge-json: invalid JSON in {path}: {exc}", file=sys.stderr)
        sys.exit(1)


def render(value):
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def main(argv):
    check = False
    args = list(argv)
    if args and args[0] == "--check":
        check = True
        args = args[1:]
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    template_path, target_path = args
    template = load(template_path, required=True)
    target = load(target_path, required=False)
    merged = merge(target, template) if target is not None else template
    merged_text = render(merged)

    if check:
        if target is None:
            return 3
        return 0 if render(target) == merged_text else 3

    sys.stdout.write(merged_text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
