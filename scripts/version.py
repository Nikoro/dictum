#!/usr/bin/env python3
import argparse
from datetime import date
from pathlib import Path
import re


def semantic_version(value, bump=None):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value):
        raise ValueError("Use an App Store compatible semantic version: MAJOR.MINOR.PATCH")
    parts = list(map(int, value.split(".")))
    if bump:
        index = ("major", "minor", "patch").index(bump)
        parts[index] += 1
        parts[index + 1:] = [0] * (2 - index)
    return ".".join(map(str, parts))


def next_build(current, today):
    stamp = int(today.strftime("%y%m%d"))
    previous_day, counter = divmod(current, 100)
    if 1000000 <= current <= 99999999 and previous_day == stamp:
        if counter >= 99:
            raise ValueError("All 99 build numbers for today are used; wait until tomorrow")
        result = stamp * 100 + counter + 1
    else:
        result = stamp * 100 + 1
    if result <= current:
        raise ValueError("The next build must exceed the current build; check the system date")
    return result


def setting_pattern(key):
    return re.compile(r'^(    ' + key + r': ")[^"]+("\s*)$', re.MULTILINE)


def prepare(project, today, explicit_version=None, bump=None):
    content = project.read_text()
    settings = {}
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        matches = list(setting_pattern(key).finditer(content))
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one shared {key} in project.yml")
        settings[key] = matches[0].group().split('"')[1]
    current = semantic_version(settings["MARKETING_VERSION"])
    selected = semantic_version(explicit_version or current, bump)
    if tuple(map(int, selected.split("."))) < tuple(map(int, current.split("."))):
        raise ValueError("The semantic version cannot go backwards")
    build = next_build(int(settings["CURRENT_PROJECT_VERSION"]), today)
    for key, value in (("MARKETING_VERSION", selected), ("CURRENT_PROJECT_VERSION", str(build))):
        content = setting_pattern(key).sub(lambda match: match[1] + value + match[2], content)
    project.write_text(content)
    return selected, build


def main():
    parser = argparse.ArgumentParser(description="Prepare Dictum SemVer and BirthMinder YYMMDDNN build numbers")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1] / "project.yml")
    version = parser.add_mutually_exclusive_group()
    version.add_argument("--version")
    version.add_argument("--bump", choices=("major", "minor", "patch"))
    args = parser.parse_args()
    try:
        selected, build = prepare(args.project, date.today(), args.version, args.bump)
    except ValueError as error:
        parser.error(str(error))
    print(f"Dictum {selected} ({build})")


if __name__ == "__main__":
    main()
