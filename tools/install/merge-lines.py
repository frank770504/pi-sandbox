#!/usr/bin/env python3
"""Insert or replace a managed marker block inside a text file.

The block content is taken from a file and wrapped by the caller-supplied begin
and end markers. If the markers already exist, everything between them
(inclusive) is replaced. If they do not exist, the block is appended. Text
outside the block is preserved. The operation is idempotent.

Usage:
  merge-lines.py --file TARGET --block-file BLOCK --begin BEGIN --end END
  merge-lines.py --check ...   compare instead of printing

Exit codes:
  0  success, or (in --check mode) target already matches
  1  invalid input (unbalanced markers)
  2  usage error
  3  --check mode only: target is missing or differs
"""

import sys


class InvalidInput(Exception):
    pass


def build(original, block, begin, end):
    wrapped = f"{begin}\n{block}\n{end}"
    if begin in original:
        if end not in original:
            raise InvalidInput(f"begin marker without end marker: {begin!r}")
        pre, rest = original.split(begin, 1)
        _, post = rest.split(end, 1)
        pre = pre.rstrip("\n")
        post = post.strip("\n")
        parts = [part for part in (pre, wrapped, post) if part]
        return "\n\n".join(parts) + "\n"

    if end in original:
        raise InvalidInput(f"end marker without begin marker: {end!r}")

    text = original.rstrip("\n")
    if text:
        return text + "\n\n" + wrapped + "\n"
    return wrapped + "\n"


def parse(argv):
    args = list(argv)
    check = False
    if args and args[0] == "--check":
        check = True
        args = args[1:]

    values = {"file": None, "block-file": None, "begin": None, "end": None}
    index = 0
    while index < len(args):
        key = args[index]
        if key.startswith("--") and key[2:] in values and index + 1 < len(args):
            values[key[2:]] = args[index + 1]
            index += 2
        else:
            raise InvalidInput(f"unexpected argument: {key}")
    missing = [name for name, value in values.items() if value is None]
    if missing:
        raise InvalidInput("missing required option(s): " + ", ".join("--" + m for m in missing))
    return check, values


def read_text(path, required):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except FileNotFoundError:
        if required:
            raise
        return ""


def main(argv):
    try:
        check, values = parse(argv)
    except InvalidInput as exc:
        print(f"merge-lines: {exc}", file=sys.stderr)
        return 2

    try:
        block = read_text(values["block-file"], required=True).strip("\n")
        original = read_text(values["file"], required=False)
    except FileNotFoundError as exc:
        print(f"merge-lines: file not found: {exc.filename}", file=sys.stderr)
        return 1

    try:
        merged = build(original, block, values["begin"], values["end"])
    except InvalidInput as exc:
        print(f"merge-lines: {exc}", file=sys.stderr)
        return 1

    if check:
        if not original:
            return 3
        return 0 if original == merged else 3

    sys.stdout.write(merged)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
