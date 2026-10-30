#!/usr/bin/env python3
"""Fail when a dlog(...) call interpolates something that may carry dictated content.

dlog lines go to a file and to the unified log as public text, so they may contain only counts,
flags, ids and durations. Interpolating a value whose name suggests text (transcript, prompt,
clipboard, selection, OCR, output...) is rejected unless it is reduced to `.count`, a nil or
empty check, or an explicitly content-free summary.

Usage: check_log_privacy.py FILE...
"""

import re
import sys

SENSITIVE = re.compile(r"(?i)(text|transcript|prompt|output|clipboard|selected|selection|ocr|cleaned|raw|spoken|words|message)")
REDUCED = re.compile(r"(\.count\b|[!=]= nil|\.isEmpty|WithoutContents|\.rawValue|bundleId|bundleIdentifier|Id\b|Ids\b|ModelId)")


def dlog_calls(source):
    for match in re.finditer(r"\bdlog\(", source):
        depth, i = 1, match.end()
        while i < len(source) and depth:
            depth += {"(": 1, ")": -1}.get(source[i], 0)
            i += 1
        yield source.count("\n", 0, match.start()) + 1, source[match.end():i - 1]


def interpolations(call):
    i = 0
    while (start := call.find("\\(", i)) != -1:
        depth, j = 1, start + 2
        while j < len(call) and depth:
            depth += {"(": 1, ")": -1}.get(call[j], 0)
            j += 1
        yield call[start + 2:j - 1]
        i = j


def main(paths):
    failed = False
    for path in paths:
        source = open(path, encoding="utf-8").read()
        for line, call in dlog_calls(source):
            for expression in interpolations(call):
                if SENSITIVE.search(expression) and not REDUCED.search(expression):
                    failed = True
                    print(f"{path}:{line}: error: dlog interpolates `{expression}`, which may carry dictated "
                          "content; log its count or a flag instead", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
