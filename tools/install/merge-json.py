#!/usr/bin/env python3
"""Merge managed keys from a template JSON file into a target JSON file.

Managed keys are the keys present in the template. Nested objects are merged
recursively; arrays and scalars in the template replace the target value unless
a path is explicitly marked additive with --append-path, in which case template
items are appended only when not already present. Unrelated target keys are
preserved. A missing target is treated as empty, so the merged output equals
the template.

Usage:
  merge-json.py [--append-path dotted.path] TEMPLATE TARGET
  merge-json.py [--append-path dotted.path] --check TEMPLATE TARGET

Example:
  merge-json.py --append-path permissions.allow TEMPLATE TARGET

Exit codes:
  0  success, or (in --check mode) target already matches
  1  invalid input (unreadable or invalid JSON)
  2  usage error
  3  --check mode only: target is missing or differs
"""

import json
import sys


def merge(base, override, path=(), append_paths=()):
    if isinstance(base, dict) and isinstance(override, dict):
        out = dict(base)
        for key, value in override.items():
            child_path = path + (key,)
            out[key] = merge(out[key], value, child_path, append_paths) if key in out else value
        return out
    if isinstance(base, list) and isinstance(override, list) and path in append_paths:
        out = list(base)
        for item in override:
            if item not in out:
                out.append(item)
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
    append_paths = []
    args = list(argv)
    index = 0
    positional = []
    while index < len(args):
        arg = args[index]
        if arg == "--check":
            check = True
            index += 1
        elif arg == "--append-path" and index + 1 < len(args):
            append_paths.append(tuple(args[index + 1].split(".")))
            index += 2
        else:
            positional.append(arg)
            index += 1
    if len(positional) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    template_path, target_path = positional
    template = load(template_path, required=True)
    target = load(target_path, required=False)
    merged = merge(target, template, append_paths=tuple(append_paths)) if target is not None else template
    merged_text = render(merged)

    if check:
        if target is None:
            return 3
        return 0 if render(target) == merged_text else 3

    sys.stdout.write(merged_text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
