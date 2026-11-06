#!/usr/bin/env python3
"""Generate and validate the portable LAGC themes for the Herdr desktop app.

The app loads ``~/.config/herdr-app/themes/<name>.json`` (documented in the
``AGENTS.md`` it writes next to ``settings.json``):

    {"background", "foreground", "selection", "cursor"?, "ansi": [16 colors],
     "colors"?: {panel color overrides}}

All values are ``#rrggbb``. The terminal colors come from the tracked Kitty
palette of each LAGC theme so a Herdr pane matches a Kitty window exactly; the
panel overrides reuse the accent, border and state colors of the rhun theme of
the same name (itself taken 1:1 from the VSCodium family). The generated JSON
files are tracked, so ``--check`` fails when a source palette drifts.

Usage: herdr-app-themes.py [--write | --check]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOTFILES = ROOT / "dotfiles/.config"
OUT_DIR = DOTFILES / "herdr-app/themes"

# slug -> (HyDE theme directory, expected kind)
THEMES = {
    "lagc-calm-dark": ("LAGC Calm Dark", "dark"),
    "lagc-calm-light": ("LAGC Calm Light", "light"),
    "lagc-tech-dark": ("LAGC Tech Dark", "dark"),
    "lagc-tech-light": ("LAGC Tech Light", "light"),
}

HEX = re.compile(r"#[0-9a-f]{6}$")


def read_pairs(path: Path, separator: str) -> dict[str, str]:
    pairs: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith(("#", "[")):
            continue
        key, _, value = line.partition(separator)
        pairs[key.strip()] = value.strip()
    return pairs


def kitty(name: str) -> dict[str, str]:
    path = DOTFILES / "hyde/themes" / name / "kitty.theme"
    pairs: dict[str, str] = {}
    for line in path.read_text().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].startswith("#"):
            pairs[parts[0]] = parts[1].lower()
    return pairs


def rhun(slug: str) -> dict[str, str]:
    pairs = read_pairs(DOTFILES / f"rhun/themes/{slug}.theme", "=")
    return {key: value.lower() if value.startswith("#") else value for key, value in pairs.items()}


def build(slug: str) -> dict:
    name, _ = THEMES[slug]
    term, ui = kitty(name), rhun(slug)
    # Text on an accent fill: whichever of the theme's own background and
    # foreground reads better, so a lifted dark-theme accent gets dark text.
    on_accent = max((term["background"], term["foreground"]), key=lambda color: contrast(color, ui["accent"]))
    # Semantic states: working = the single interactive accent, blocked = ember
    # (the only attention hue), done = the success tone, idle/unknown = quiet.
    return {
        "background": term["background"],
        "foreground": term["foreground"],
        "selection": term["selection_background"],
        "cursor": term["cursor"],
        "ansi": [term[f"color{i}"] for i in range(16)],
        "colors": {
            "surface": ui["panel"],
            "popover": ui["popup"],
            "hover": ui["hover"],
            "border": ui["border"],
            "muted": ui["muted"],
            "dim": ui["line_number"],
            "accent": ui["accent"],
            "accent_foreground": on_accent,
            "working": ui["accent"],
            "blocked": ui["error"],
            "done": ui["success"],
            "idle": ui["muted"],
            "unknown": ui["line_number"],
        },
    }


def render(theme: dict) -> str:
    ansi = ",\n    ".join(
        ", ".join(json.dumps(color) for color in theme["ansi"][i : i + 8]) for i in (0, 8)
    )
    scalars = "".join(
        f'  "{key}": {json.dumps(theme[key])},\n' for key in ("background", "foreground", "selection", "cursor")
    )
    colors = ",\n".join(f"    {json.dumps(key)}: {json.dumps(value)}" for key, value in theme["colors"].items())
    return f'{{\n{scalars}  "ansi": [\n    {ansi}\n  ],\n  "colors": {{\n{colors}\n  }}\n}}\n'


def validate(slug: str, theme: dict) -> list[str]:
    errors: list[str] = []
    colors = [theme["background"], theme["foreground"], theme["selection"], theme["cursor"], *theme["ansi"], *theme["colors"].values()]
    if len(theme["ansi"]) != 16:
        errors.append(f"{slug}: ansi must hold 16 colors")
    errors += [f"{slug}: invalid color {color!r}" for color in colors if not HEX.fullmatch(color)]
    if not errors:
        lum = luminance(theme["background"])
        kind = THEMES[slug][1]
        if (kind == "dark") != (lum < 0.5):
            errors.append(f"{slug}: background luminance {lum:.2f} contradicts kind {kind}")
        ratio = contrast(theme["foreground"], theme["background"])
        if ratio < 7:
            errors.append(f"{slug}: foreground contrast {ratio:.1f}:1 is below 7:1")
        ratio = contrast(theme["colors"]["accent_foreground"], theme["colors"]["accent"])
        if ratio < 4.5:
            errors.append(f"{slug}: accent_foreground contrast {ratio:.1f}:1 is below 4.5:1")
    return errors


def channel(value: int) -> float:
    value /= 255
    return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4


def luminance(color: str) -> float:
    red, green, blue = (channel(int(color[i : i + 2], 16)) for i in (1, 3, 5))
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast(first: str, second: str) -> float:
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="regenerate the tracked JSON files")
    mode.add_argument("--check", action="store_true", help="validate and compare with the tracked files (default)")
    args = parser.parse_args()

    failures: list[str] = []
    for slug in THEMES:
        theme = build(slug)
        failures += validate(slug, theme)
        text = render(theme)
        target = OUT_DIR / f"{slug}.json"
        if args.write:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
        elif not target.is_file():
            failures.append(f"{slug}: {target.relative_to(ROOT)} is missing")
        else:
            if target.read_text() != text:
                failures.append(f"{slug}: {target.relative_to(ROOT)} is stale; run tools/herdr-app-themes.py --write")
            json.loads(target.read_text())
    for failure in failures:
        print(failure, file=sys.stderr)
    if not failures:
        print("Herdr app LAGC themes are valid.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
