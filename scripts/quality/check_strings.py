#!/usr/bin/env python3
"""Localization gate for Resources/*.xcstrings.

Fails when a catalog is not valid JSON, a key lacks a translated English or Polish value
(including every plural form), the code uses a key the catalog lacks (the UI would fall back
to the English default even in Polish), or the catalog carries a key no code references.
"""

import glob
import json
import os
import re
import subprocess
import sys

LANGUAGES = ("en", "pl")
LOCALIZABLE = "Resources/Localizable.xcstrings"
SOURCE_EXCLUDES = ("build/", ".agents/", ".tools/", "website/", "Dictum.xcodeproj/")
LOCALIZED_KEY = re.compile(r'(?:String\(\s*localized:\s*|LocalizationValue\()"((?:[^"\\]|\\.)*)"')
KEY_LIKE_LITERAL = re.compile(r'"([a-z][a-z0-9_]*(?:\.[A-Za-z0-9_]+)+(?: \\\([^)]*\))?)"')
INTERPOLATION = re.compile(r"\\\([^)]*\)")


def untranslated(localization):
    if "stringUnit" in localization:
        unit = localization["stringUnit"]
        return [] if unit.get("state") == "translated" and unit.get("value") else ["value"]
    forms = localization.get("variations", {}).get("plural", {})
    if "other" not in forms:
        return ["plural other"]
    return [f"plural {form}" for form, unit in forms.items() if untranslated(unit)]


def catalog_errors(path):
    try:
        catalog = json.load(open(path, encoding="utf-8"))
    except ValueError as error:
        return [f"{path}: invalid JSON: {error}"], set()
    errors = []
    for key, entry in catalog.get("strings", {}).items():
        for language in LANGUAGES:
            localization = entry.get("localizations", {}).get(language)
            if localization is None:
                errors.append(f"{path}: \"{key}\" has no {language} translation")
                continue
            errors += [f"{path}: \"{key}\" {language} {part} not translated" for part in untranslated(localization)]
    return errors, set(catalog.get("strings", {}))


def swift_sources():
    files = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.swift"],
                           capture_output=True, text=True).stdout.split()
    return [f for f in files if not f.startswith(SOURCE_EXCLUDES) and os.path.isfile(f)]


def as_catalog_key(literal):
    return INTERPOLATION.sub("%@", literal)


def main():
    errors = []
    for path in sorted(glob.glob("Resources/*.xcstrings")):
        errors += catalog_errors(path)[0]
    keys = catalog_errors(LOCALIZABLE)[1]

    used, referenced = set(), set()
    emoji_path = "Resources/Emoji/EmojiCatalog.json"
    if os.path.exists(emoji_path):
        with open(emoji_path, encoding="utf-8") as file:
            used |= {entry["localizationKey"] for entry in json.load(file)}
    for path in swift_sources():
        source = open(path, encoding="utf-8").read()
        used |= {as_catalog_key(k) for k in LOCALIZED_KEY.findall(source)}
        referenced |= {as_catalog_key(k) for k in KEY_LIKE_LITERAL.findall(source)}
    errors += [f"key used in code but missing from {LOCALIZABLE}: \"{k}\"" for k in sorted(used - keys)]
    errors += [f"key not referenced by any Swift file: \"{k}\"" for k in sorted(keys - used - referenced)]

    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
