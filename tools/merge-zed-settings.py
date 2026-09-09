#!/usr/bin/env python3
"""Merge the overlay-owned LAGC selection into a user-owned Zed settings file."""

from __future__ import annotations

import argparse
import json
import os
import stat
import tempfile
from pathlib import Path
from typing import Any


EXPECTED_THEMES = {
    "light": "LAGC Tech Light",
    "dark": "LAGC Tech Dark",
}
EXPECTED_APPEARANCES = {
    "LAGC Tech Dark": "dark",
    "LAGC Tech Light": "light",
}


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError as error:
        raise ValueError(f"{path} is not valid JSON: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def validate_selection(path: Path) -> dict[str, str]:
    value = load_json(path)
    theme = value.get("theme")
    if not isinstance(theme, dict):
        raise ValueError(f"{path} must define a theme object")
    if {key: theme.get(key) for key in EXPECTED_THEMES} != EXPECTED_THEMES:
        raise ValueError(f"{path} must select {EXPECTED_THEMES!r}")
    return EXPECTED_THEMES


def validate_theme_family(path: Path) -> None:
    family = load_json(path)
    if family.get("name") != "LAGC Tech" or not isinstance(family.get("author"), str):
        raise ValueError(f"{path} must identify the LAGC Tech family and author")
    themes = family.get("themes")
    if not isinstance(themes, list) or len(themes) != 2:
        raise ValueError(f"{path} must contain exactly the Dark and Light themes")

    appearances: dict[str, str] = {}
    for theme in themes:
        if not isinstance(theme, dict) or not isinstance(theme.get("style"), dict):
            raise ValueError(f"{path} contains an invalid theme entry")
        name = theme.get("name")
        appearance = theme.get("appearance")
        if not isinstance(name, str) or not isinstance(appearance, str):
            raise ValueError(f"{path} theme entries need name and appearance")
        appearances[name] = appearance
        for key in ("background", "text", "editor.background", "editor.foreground", "syntax"):
            if key not in theme["style"]:
                raise ValueError(f"{path} theme {name!r} is missing style.{key}")

    if appearances != EXPECTED_APPEARANCES:
        raise ValueError(f"{path} must provide {EXPECTED_APPEARANCES!r}")


def merge(selection: dict[str, str], target: Path) -> None:
    settings = load_json(target)
    existing = settings.get("theme")
    if isinstance(existing, dict):
        theme = dict(existing)
    elif isinstance(existing, str) or existing is None:
        theme = {"mode": "system"}
    else:
        raise ValueError(f"{target} has an unsupported theme setting")

    theme.setdefault("mode", "system")
    theme.update(selection)
    settings["theme"] = theme

    target.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(target.stat().st_mode) if target.exists() else 0o600
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=target.parent, prefix=f".{target.name}.", delete=False
    ) as temporary:
        json.dump(settings, temporary, indent=4, ensure_ascii=False)
        temporary.write("\n")
        temporary_name = temporary.name

    os.chmod(temporary_name, mode)
    os.replace(temporary_name, target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--settings", type=Path, required=True, help="Tracked LAGC theme selection JSON")
    parser.add_argument("--theme", type=Path, required=True, help="Tracked Zed theme-family JSON")
    parser.add_argument("--target", type=Path, help="User-owned Zed settings.json to update")
    parser.add_argument("--check", action="store_true", help="Validate sources without writing settings")
    args = parser.parse_args()

    selection = validate_selection(args.settings)
    validate_theme_family(args.theme)
    if args.check:
        print("LAGC Tech Zed theme sources are valid.")
        return
    if args.target is None:
        parser.error("--target is required unless --check is used")
    merge(selection, args.target)


if __name__ == "__main__":
    main()
