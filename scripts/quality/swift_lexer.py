"""Minimal Swift lexer for the quality gates: finds comments and code braces, skipping string
literals (including multi-line literals and `\\(...)` interpolations)."""

from dataclasses import dataclass


@dataclass
class Comment:
    line: int
    text: str
    is_doc: bool
    is_block: bool
    is_trailing: bool


@dataclass
class Brace:
    line: int
    delta: int


def tokens(source):
    """Yields Comment and Brace tokens in source order."""
    i, line, n = 0, 1, len(source)
    line_has_code = False
    while i < n:
        ch = source[i]
        if ch == "\n":
            line += 1
            line_has_code = False
            i += 1
        elif source.startswith("//", i):
            end = source.find("\n", i)
            end = n if end == -1 else end
            raw = source[i:end]
            is_doc = raw.startswith("///")
            yield Comment(line, raw.lstrip("/").strip(), is_doc, False, line_has_code)
            i = end
        elif source.startswith("/*", i):
            start_line, start = line, i
            i, line = _skip_block_comment(source, i, line)
            raw = source[start:i]
            is_doc = raw.startswith("/**")
            body = raw[2:-2].strip("*").strip()
            text = " ".join(part.strip().lstrip("*").strip() for part in body.split("\n")).strip()
            yield Comment(start_line, text, is_doc, True, line_has_code)
        elif ch == '"':
            i, line = _skip_string(source, i, line)
            line_has_code = True
        elif ch in "{}":
            yield Brace(line, 1 if ch == "{" else -1)
            line_has_code = True
            i += 1
        else:
            if not ch.isspace():
                line_has_code = True
            i += 1


def _skip_block_comment(source, i, line):
    depth = 0
    while i < len(source):
        if source.startswith("/*", i):
            depth += 1
            i += 2
        elif source.startswith("*/", i):
            depth -= 1
            i += 2
            if depth == 0:
                return i, line
        else:
            if source[i] == "\n":
                line += 1
            i += 1
    return i, line


def _skip_string(source, i, line):
    delimiter = '"""' if source.startswith('"""', i) else '"'
    i += len(delimiter)
    while i < len(source):
        ch = source[i]
        if ch == "\n":
            line += 1
        if ch == "\\" and source.startswith("(", i + 1):
            i, line = _skip_interpolation(source, i + 2, line)
            continue
        if ch == "\\":
            i += 2
            continue
        if source.startswith(delimiter, i):
            return i + len(delimiter), line
        i += 1
    return i, line


def _skip_interpolation(source, i, line):
    depth = 1
    while i < len(source) and depth:
        ch = source[i]
        if ch == "\n":
            line += 1
        if ch == '"':
            i, line = _skip_string(source, i, line)
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        i += 1
    return i, line
