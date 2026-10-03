#!/usr/bin/env python3
"""Validate the portable LAGC rhun editor themes.

rhun loads user themes from ``~/.config/rhun/themes/*.theme``. Each file is an
INI-like list of ``key = value`` pairs. The key names below are the slot table
of rhun's ``src/app/theme.s`` (``slot_names``): rhun matches every key against
that one flat table and ignores section headers, so ``[terminal]`` only groups
the ANSI colors for readers. A key outside the table is silently ignored by
rhun and its slot falls back to a color derived from ``bg``/``fg``/``accent``,
which is why this validator rejects unknown keys instead of trusting them.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
THEME_ROOT = REPOSITORY_ROOT / "dotfiles/.config/rhun/themes"

# label -> (expected kind, file name)
THEMES = {
    "LAGC Calm Dark": ("dark", "lagc-calm-dark.theme"),
    "LAGC Calm Light": ("light", "lagc-calm-light.theme"),
    "LAGC Tech Dark": ("dark", "lagc-tech-dark.theme"),
    "LAGC Tech Light": ("light", "lagc-tech-light.theme"),
}

# rhun's parse_color accepts #rrggbb and #rrggbbaa; the LAGC themes are opaque.
HEX_COLOR = re.compile(r"#[0-9A-Fa-f]{6}$")

# UI slots (.Ls0-.Ls26 in rhun src/app/theme.s).
UI_KEYS = (
    "bg", "fg", "accent", "panel", "titlebar", "border", "muted",
    "line_number", "line_number_active", "line_highlight", "selection",
    "cursor", "hover", "active", "popup", "input", "scrollbar", "status",
    "tab", "tab_active", "error", "warning", "success", "match", "guide",
    "accent_fg", "panel_fg",
)

# Syntax classes (.Lc0-.Lc19).
SYNTAX_KEYS = (
    "text", "keyword", "type", "function", "string", "number", "comment",
    "constant", "operator", "punctuation", "preproc", "variable", "builtin",
    "attribute", "tag", "heading", "inserted", "deleted", "escape", "link",
)

# Terminal ANSI colors (.Lt0-.Lt15).
TERMINAL_KEYS = (
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
    "bright_black", "bright_red", "bright_green", "bright_yellow",
    "bright_blue", "bright_magenta", "bright_cyan", "bright_white",
)

# Git colors (.Lg0-.Lg2).
GIT_KEYS = ("git_added", "git_modified", "git_deleted")

COLOR_KEYS = (*UI_KEYS, *SYNTAX_KEYS, *TERMINAL_KEYS, *GIT_KEYS)
ALLOWED_SECTIONS = {"syntax", "terminal"}


def parse_theme(path: Path) -> dict[str, str]:
    """Return every ``key = value`` pair of a .theme file, sections flattened."""
    entries: dict[str, str] = {}
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            if section not in ALLOWED_SECTIONS:
                raise ValueError(f"{path}:{lineno}: unexpected section [{section}]")
            continue
        if "=" not in line:
            raise ValueError(f"{path}:{lineno}: expected 'key = value', got {raw!r}")
        key, value = (part.strip() for part in line.split("=", 1))
        if not key:
            raise ValueError(f"{path}:{lineno}: empty key")
        if key in entries:
            raise ValueError(f"{path}:{lineno}: duplicate key {key!r}")
        entries[key] = value
    return entries


def validate_theme(path: Path, expected_name: str, expected_kind: str) -> None:
    if not path.is_file():
        raise ValueError(f"Theme file is missing: {path}")
    entries = parse_theme(path)

    if entries.get("name") != expected_name:
        raise ValueError(f"Unexpected theme name in {path}: {entries.get('name')!r}")
    if entries.get("kind") != expected_kind:
        raise ValueError(f"Unexpected theme kind in {path}: {entries.get('kind')!r}")

    for key in COLOR_KEYS:
        if key not in entries:
            raise ValueError(f"{path}: missing color key {key!r}")
        if not HEX_COLOR.fullmatch(entries[key]):
            raise ValueError(f"{path}: expected #rrggbb for {key!r}: {entries[key]!r}")

    unknown = sorted(set(entries) - {"name", "kind", *COLOR_KEYS})
    if unknown:
        raise ValueError(f"{path}: keys rhun does not know (ignored by rhun): {unknown}")


def validate_all(root: Path) -> None:
    tracked = {p.name for p in root.glob("*.theme")}
    expected = {file_name for _, file_name in THEMES.values()}
    extra = tracked - expected
    if extra:
        raise ValueError(f"Unexpected rhun theme files tracked: {sorted(extra)}")
    for label, (kind, file_name) in THEMES.items():
        validate_theme(root / file_name, label, kind)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate the tracked rhun themes")
    parser.parse_args()

    try:
        validate_all(THEME_ROOT)
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        return 1

    print("LAGC rhun theme source is valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
