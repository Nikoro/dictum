#!/usr/bin/env python3
"""Code explains itself: fail on any Swift comment that is not one of

  - a tool directive: `swiftlint:`, `swiftformat:`, `sourcery:`
  - a `TODO:` / `FIXME:` with enough context to act on
  - an `// Edge case:` note of at most 4 lines, stating what the code cannot say on its own:
    a platform quirk, an ordering dependency, why the obvious simpler version is wrong.

Doc comments (`///`, `/** */`), `MARK:` banners, narration and trailing remarks all fail.

Usage: check_comments.py FILE...
"""

import re
import sys

from swift_lexer import Comment, tokens

EDGE_CASE_MAX_LINES = 4
DIRECTIVE = re.compile(r"^(swiftlint:|swiftformat:|sourcery:)")
ACTION_ITEM = re.compile(r"^(TODO|FIXME):\s*\S")
EDGE_CASE = re.compile(r"^Edge case:\s*\S")


def violations(path):
    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    open_note, note_lines, previous_line = None, 0, -1
    for token in tokens(source):
        if not isinstance(token, Comment):
            continue
        continues_note = (
            open_note is not None and token.line == previous_line + 1
            and not token.is_doc and not token.is_block and not token.is_trailing
        )
        previous_line = token.line
        if continues_note and not (DIRECTIVE.match(token.text) or ACTION_ITEM.match(token.text)
                                   or EDGE_CASE.match(token.text)):
            note_lines += 1
            if open_note == "edge" and note_lines > EDGE_CASE_MAX_LINES:
                yield token.line, f"Edge case note longer than {EDGE_CASE_MAX_LINES} lines", token.text
            continue
        open_note, note_lines = None, 1
        if token.is_doc:
            yield token.line, "doc comment", token.text
        elif DIRECTIVE.match(token.text):
            continue
        elif token.is_trailing:
            yield token.line, "trailing comment", token.text
        elif ACTION_ITEM.match(token.text):
            open_note = "action"
        elif EDGE_CASE.match(token.text) and not token.is_block:
            open_note = "edge"
        else:
            yield token.line, "comment", token.text


def main(paths):
    failed = False
    for path in paths:
        for line, reason, text in violations(path):
            failed = True
            print(f'{path}:{line}: error: {reason}: "{text[:80]}"', file=sys.stderr)
    if failed:
        print("Allowed: `// Edge case:` (max 4 lines), `// TODO:` / `// FIXME:`, tool directives. "
              "Otherwise make the code say it: a better name, a smaller function, a type.", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
