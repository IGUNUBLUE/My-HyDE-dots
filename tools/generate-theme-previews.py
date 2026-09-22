#!/usr/bin/env python3
"""Generate README preview mockups for the LAGC HyDE themes.

Renders one stylized desktop mockup per theme (wallpaper, Waybar, Kitty
terminal with real ANSI colors, Rofi launcher, notification card and a
palette strip) straight from each theme's tracked `theme.dcol` and
`kitty.theme`, so the images always match the shipped palettes.

Usage:
    python tools/generate-theme-previews.py            # write assets/previews/*.png
    python tools/generate-theme-previews.py --svg-dir DIR  # also keep the SVGs
Requires rsvg-convert on PATH.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
THEMES_DIR = REPO / "dotfiles/.config/hyde/themes"
OUT_DIR = REPO / "assets/previews"

THEMES = {
    "LAGC Calm Dark": {"accent_var": "2xa4", "accent2_var": "4xa6"},
    "LAGC Calm Light": {"accent_var": "2xa8", "accent2_var": "4xa4"},
    "LAGC Tech Dark": {"accent_var": "4xa6", "accent2_var": "2xa4"},
    "LAGC Tech Light": {"accent_var": "2xa8", "accent2_var": "4xa6"},
}

W, H = 1400, 880
FONT = "Atkinson Hyperlegible Next, Atkinson Hyperlegible, sans-serif"
MONO = "CaskaydiaCove Nerd Font Mono, monospace"


def dcol(path: Path) -> dict[str, str]:
    return {k: "#" + v for k, v in re.findall(r'dcol_(\w+)="([0-9A-Fa-f]{6})"', path.read_text())}


def kitty_ansi(path: Path) -> dict[str, str]:
    return {k: "#" + v for k, v in re.findall(r"^color(\d+)\s+#?([0-9A-Fa-f]{6})", path.read_text(), re.M)}


def svg(p: dict[str, str], name: str) -> str:
    bg, fg = p["pry1"], p["txt1"]
    surf, surf2, border, muted = p["1xa1"], p["1xa2"], p["1xa3"], p["1xa6"]
    accent, accent2 = p["accent"], p["accent2"]
    sel = p["sel"]
    a = p["ansi"]  # ansi colors dict

    doc = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="{FONT}" xml:space="preserve">
<defs>
  <radialGradient id="wall" cx="70%" cy="20%" r="120%">
    <stop offset="0%" stop-color="{surf2}" stop-opacity="0.55"/>
    <stop offset="55%" stop-color="{bg}"/>
    <stop offset="100%" stop-color="{bg}"/>
  </radialGradient>
</defs>
<rect width="{W}" height="{H}" fill="{bg}"/>
<rect width="{W}" height="{H}" fill="url(#wall)"/>

<!-- Waybar -->
<rect x="20" y="16" width="{W-40}" height="46" rx="14" fill="{surf}"/>
<g font-size="17">
  <rect x="36" y="27" width="150" height="24" rx="12" fill="{accent}"/>
  <text x="111" y="44" text-anchor="middle" fill="{bg}" font-weight="bold"> 1 2 3</text>
  <text x="220" y="45" fill="{muted}">kitty</text>
  <text x="{W/2}" y="45" text-anchor="middle" fill="{fg}" font-weight="bold">Mon Sep 22  14:32</text>
  <rect x="{W-352}" y="27" width="96" height="24" rx="12" fill="{surf2}"/>
  <text x="{W-304}" y="44" text-anchor="middle" fill="{a['4']}"> 62%</text>
  <rect x="{W-244}" y="27" width="96" height="24" rx="12" fill="{surf2}"/>
  <text x="{W-196}" y="44" text-anchor="middle" fill="{a['3']}"> 41%</text>
  <rect x="{W-136}" y="27" width="96" height="24" rx="12" fill="{surf2}"/>
  <text x="{W-88}" y="44" text-anchor="middle" fill="{accent}"> </text>
</g>

<!-- Kitty terminal -->
<g>
  <rect x="60" y="100" width="640" height="470" rx="14" fill="{surf}"/>
  <rect x="60" y="100" width="640" height="42" rx="14" fill="{surf2}"/>
  <rect x="60" y="128" width="640" height="14" fill="{surf2}"/>
  <circle cx="88" cy="121" r="7" fill="{a['1']}"/><circle cx="112" cy="121" r="7" fill="{a['3']}"/><circle cx="136" cy="121" r="7" fill="{a['2']}"/>
  <text x="380" y="127" text-anchor="middle" fill="{muted}" font-size="15">kitty</text>
  <rect x="76" y="152" width="608" height="402" rx="8" fill="{bg}"/>
  <g font-family="{MONO}" font-size="19">
    <text x="92" y="188"><tspan fill="{a['2']}">lenin@lagc</tspan><tspan fill="{fg}">:</tspan><tspan fill="{a['4']}">~/projects</tspan><tspan fill="{fg}"> $ </tspan><tspan fill="{a['6']}">hyde-shell reload</tspan></text>
    <text x="92" y="222" fill="{a['2']}">✓ theme applied: {name}</text>
    <text x="92" y="256" fill="{fg}">wallbash → waybar · rofi · gtk · qt</text>
    <text x="92" y="290"><tspan fill="{a['3']}">warn </tspan><tspan fill="{muted}">  opacity locked to 1.0 (solid-first)</tspan></text>
    <text x="92" y="324"><tspan fill="{a['1']}">error </tspan><tspan fill="{muted}"> dunst: unit not found (using swaync)</tspan></text>
    <text x="92" y="358"><tspan fill="{a['5']}">git </tspan><tspan fill="{fg}"> main f9a0c02 · 4 ahead</tspan></text>
    <text x="92" y="392"><tspan fill="{a['2']}">lenin@lagc</tspan><tspan fill="{fg}">:</tspan><tspan fill="{a['4']}">~/projects</tspan><tspan fill="{fg}"> $ </tspan><tspan fill="{fg}">▌</tspan></text>
    <text x="92" y="450" fill="{muted}" font-size="15">solid surfaces · no blur · eye-comfort palette</text>
  </g>
</g>

<!-- Rofi launcher -->
<g>
  <rect x="740" y="100" width="600" height="330" rx="14" fill="{surf}"/>
  <rect x="762" y="122" width="556" height="44" rx="10" fill="{bg}" stroke="{border}"/>
  <text x="780" y="151" fill="{fg}" font-size="19" font-family="{MONO}">firefox</text>
  <rect x="762" y="182" width="556" height="46" rx="10" fill="{accent}"/>
  <text x="786" y="212" fill="{bg}" font-size="18" font-weight="bold">  Firefox</text>
  <text x="786" y="262" fill="{fg}" font-size="18">  File Manager</text>
  <text x="786" y="312" fill="{fg}" font-size="18">  Font Viewer</text>
  <text x="786" y="362" fill="{muted}" font-size="18">  Folder Color</text>
</g>

<!-- Notification -->
<g>
  <rect x="740" y="454" width="600" height="116" rx="14" fill="{surf2}" stroke="{border}"/>
  <circle cx="776" cy="492" r="16" fill="{accent}"/>
  <text x="776" y="499" text-anchor="middle" fill="{bg}" font-size="20" font-weight="bold">✓</text>
  <text x="806" y="499" fill="{fg}" font-size="18" font-weight="bold">Theme applied</text>
  <text x="806" y="532" fill="{muted}" font-size="16">Solid surfaces · Atkinson Hyperlegible · wallbash palette</text>
</g>

<!-- Palette strip -->
<g>
  <text x="60" y="640" fill="{fg}" font-size="26" font-weight="bold">{name}</text>
  <text x="60" y="668" fill="{muted}" font-size="15">HyDE theme — hyprland · waybar · rofi · kitty · gtk · qt · vscodium</text>
'''
    labels = [("bg", bg), ("surface", surf), ("border", border), ("muted", muted),
              ("accent", accent), ("accent2", accent2), ("select", sel),
              ("red", a['1']), ("yellow", a['3']), ("blue", a['4'])]
    x = 60
    for lab, col in labels:
        h = col.lstrip("#")
        lum = (0.2126*int(h[0:2],16) + 0.7152*int(h[2:4],16) + 0.0722*int(h[4:6],16)) / 255
        def _lum(c):
            hh = c.lstrip("#")
            return (0.2126*int(hh[0:2],16) + 0.7152*int(hh[2:4],16) + 0.0722*int(hh[4:6],16)) / 255
        lab_fg = max((p["pry1"], p["txt1"]), key=lambda c: abs(_lum(c) - lum))
        svg_text = f'''<rect x="{x}" y="700" width="118" height="118" rx="12" fill="{col}" stroke="{border}"/>
  <text x="{x+59}" y="756" text-anchor="middle" fill="{lab_fg}" font-size="13">{lab}</text>
  <text x="{x+59}" y="774" text-anchor="middle" fill="{lab_fg}" font-size="12" font-family="{MONO}">{col.upper()}</text>
'''
        doc += "  " + svg_text
        x += 130
    return doc + "</g>\n</svg>\n"


def build_palette(theme: str) -> dict[str, str]:
    d = dcol(THEMES_DIR / theme / "theme.dcol")
    ansi = kitty_ansi(THEMES_DIR / theme / "kitty.theme")
    cfg = THEMES[theme]
    dark = d["pry1"].lower() < "#808080"
    return {
        **d,
        "accent": d[cfg["accent_var"]],
        "accent2": d[cfg["accent2_var"]],
        "sel": d["4xa9"] if dark else d["4xa4"],
        "ansi": ansi,
        "swatch_fg": d["txt1"] if dark else "#F7FCFD",
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--svg-dir", type=Path, help="also write intermediate SVGs here")
    args = ap.parse_args()
    if not shutil_which("rsvg-convert"):
        sys.exit("rsvg-convert is required")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if args.svg_dir:
        args.svg_dir.mkdir(parents=True, exist_ok=True)
    for theme in THEMES:
        content = svg(build_palette(theme), theme)
        slug = theme.lower().replace(" ", "-")
        if args.svg_dir:
            (args.svg_dir / f"{slug}.svg").write_text(content)
        png = OUT_DIR / f"{slug}.png"
        tmp = png.with_suffix(".svg")
        tmp.write_text(content)
        subprocess.run(["rsvg-convert", "-w", str(W * 2), "-o", str(png), str(tmp)], check=True)
        tmp.unlink()
        print(f"  {png.relative_to(REPO)}")
    return 0


def shutil_which(cmd: str):
    import shutil
    return shutil.which(cmd)


if __name__ == "__main__":
    raise SystemExit(main())
