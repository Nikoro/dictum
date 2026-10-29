#!/usr/bin/env python3
"""Localization gate for Resources/*.lproj/Localizable.strings.

Fails when a table is not UTF-16 LE with a BOM (the encoding the files use; a plain text
writer silently converts them and mangles Polish characters), fails `plutil -lint`, has keys
the other table lacks, misses a key the code uses (the UI then falls back to the English
default even in Polish), or carries a key no code references.
"""

import glob
import re
import subprocess
import sys

TABLES = sorted(glob.glob("Resources/*.lproj/Localizable.strings"))
SOURCE_EXCLUDES = ("build/", ".agents/", ".tools/", "website/", "Dictum.xcodeproj/")
LOCALIZED_KEY = re.compile(r'(?:String\(\s*localized:\s*|LocalizationValue\()"((?:[^"\\]|\\.)*)"')
KEY_LIKE_LITERAL = re.compile(r'"([a-z][a-z0-9_]*(?:\.[A-Za-z0-9_]+)+(?: \\\([^)]*\))?)"')
INTERPOLATION = re.compile(r"\\\([^)]*\)")


def table_keys(path, errors):
    raw = open(path, "rb").read()
    if not raw.startswith(b"\xff\xfe"):
        errors.append(f"{path}: not UTF-16 LE with BOM")
        return set()
    lint = subprocess.run(["plutil", "-lint", path], capture_output=True, text=True)
    if lint.returncode:
        errors.append(lint.stdout.strip())
    text = raw[2:].decode("utf-16-le")
    return set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', text, re.M))


def swift_sources():
    files = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.swift"],
                           capture_output=True, text=True).stdout.split()
    return [f for f in files if not f.startswith(SOURCE_EXCLUDES)]


def as_table_key(literal):
    return INTERPOLATION.sub("%@", literal)


def main():
    errors = []
    keys_by_table = {path: table_keys(path, errors) for path in TABLES}
    all_keys = set().union(*keys_by_table.values()) if keys_by_table else set()
    for path, keys in keys_by_table.items():
        for key in sorted(all_keys - keys):
            errors.append(f"{path}: missing key \"{key}\"")

    used, referenced = set(), set()
    for path in swift_sources():
        source = open(path, encoding="utf-8").read()
        used |= {as_table_key(k) for k in LOCALIZED_KEY.findall(source)}
        referenced |= {as_table_key(k) for k in KEY_LIKE_LITERAL.findall(source)}
    for key in sorted(used - all_keys):
        errors.append(f"key used in code but missing from every table: \"{key}\"")
    for key in sorted(all_keys - used - referenced):
        errors.append(f"key not referenced by any Swift file: \"{key}\"")

    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
