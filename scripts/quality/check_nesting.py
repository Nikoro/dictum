#!/usr/bin/env python3
"""Fail when a Swift file nests braces deeper than the limit (default 6).

Usage: check_nesting.py [--max N] FILE...
"""

import sys

from swift_lexer import Brace, tokens

MAX_DEPTH = 6


def deepest_brace(path):
    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    depth, deepest, deepest_line = 0, 0, 0
    for token in tokens(source):
        if isinstance(token, Brace):
            depth += token.delta
            if depth > deepest:
                deepest, deepest_line = depth, token.line
    return deepest, deepest_line


def main(argv):
    limit = MAX_DEPTH
    if argv[:1] == ["--max"]:
        limit, argv = int(argv[1]), argv[2:]
    failed = False
    for path in argv:
        depth, line = deepest_brace(path)
        if depth > limit:
            failed = True
            print(f"{path}:{line}: error: nesting depth {depth} exceeds {limit}; "
                  "extract a subview or helper", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
