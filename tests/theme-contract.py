"""Static contract for the four LAGC themes: every surface must agree.

A theme reaches apps through several files written independently (hypr.theme
for GTK/icon/cursor/colour-scheme, theme.dcol for Wallbash, kitty/waybar/rofi
themes, the rhun theme). This test fails when one of them drifts from the
others, e.g. a light dcol_mode paired with COLOR_SCHEME=prefer-dark, which
makes browsers pick the wrong variant.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEMES = ROOT / "dotfiles/.config/hyde/themes"
RHUN = ROOT / "dotfiles/.config/rhun/themes"
FOLLOW = ROOT / "dotfiles/.config/hyde/wallbash/scripts/my-hyde-rhun-theme.sh"
LAGC = ("LAGC Calm Dark", "LAGC Calm Light", "LAGC Tech Dark", "LAGC Tech Light")
FAILURES: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        FAILURES.append(message)


def hypr_vars(path: Path) -> dict[str, str]:
    return dict(re.findall(r"^\$([A-Z_]+)\s*=\s*(.*?)\s*$", path.read_text(), re.M))


def dcol(path: Path) -> dict[str, str]:
    return dict(re.findall(r'^(dcol_[A-Za-z0-9_]+)="([^"]*)"', path.read_text(), re.M))


def rhun_theme(slug: str) -> dict[str, str]:
    values = {}
    for line in (RHUN / f"{slug}.theme").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith(("#", "[")):
            key, value = (part.strip() for part in line.split("=", 1))
            values[key] = value
    return values


follow_map = dict(re.findall(r'"(LAGC [A-Za-z ]+)"\)\s+want="([a-z-]+)"', FOLLOW.read_text()))
check(set(follow_map) == set(LAGC), f"rhun follow map must cover exactly the LAGC themes: {follow_map}")

for name in LAGC:
    directory = THEMES / name
    variables = hypr_vars(directory / "hypr.theme")
    palette = dcol(directory / "theme.dcol")
    mode = palette.get("dcol_mode")
    base = palette.get("dcol_pry1", "").upper()
    text = palette.get("dcol_txt1", "").upper()

    check(mode in ("dark", "light"), f"{name}: dcol_mode must be dark or light, got {mode!r}")
    check(variables.get("COLOR_SCHEME") == f"prefer-{mode}",
          f"{name}: $COLOR_SCHEME {variables.get('COLOR_SCHEME')!r} disagrees with dcol_mode {mode!r}; "
          "browsers and libadwaita would pick the wrong variant")
    check(variables.get("GTK_THEME") == "Wallbash-Gtk",
          f"{name}: $GTK_THEME must be Wallbash-Gtk so GTK apps and GTK-mode browsers follow the palette")
    check(variables.get("CURSOR_THEME") == "Future-cursors", f"{name}: $CURSOR_THEME must be Future-cursors")
    check(bool(variables.get("ICON_THEME")), f"{name}: $ICON_THEME must be declared")
    check(re.fullmatch(r"[0-9A-F]{6}", base or "") is not None, f"{name}: dcol_pry1 must be a hex color")

    kitty = (directory / "kitty.theme").read_text()
    check(re.search(rf"^background\s+#{base}\s*$", kitty, re.M | re.I) is not None,
          f"{name}: kitty background must equal dcol_pry1 #{base}")
    check(re.search(rf"^foreground\s+#{text}\s*$", kitty, re.M | re.I) is not None,
          f"{name}: kitty foreground must equal dcol_txt1 #{text}")
    waybar = (directory / "waybar.theme").read_text()
    check(re.search(rf"^@define-color main-bg #{base};$", waybar, re.M | re.I) is not None,
          f"{name}: waybar main-bg must equal dcol_pry1 #{base}")
    rofi = (directory / "rofi.theme").read_text()
    check(re.search(rf"^\s*main-bg:\s+#{base}[0-9A-F]{{2}};$", rofi, re.M | re.I) is not None,
          f"{name}: rofi main-bg must start with dcol_pry1 #{base}")

    slug = follow_map.get(name)
    if slug:
        rhun = rhun_theme(slug)
        check(rhun.get("name") == name, f"{name}: rhun theme {slug} is named {rhun.get('name')!r}")
        check(rhun.get("kind") == mode, f"{name}: rhun theme kind {rhun.get('kind')!r} must match dcol_mode {mode!r}")

if FAILURES:
    for failure in FAILURES:
        print("FAIL:", failure)
    raise SystemExit(1)
print(f"Theme contract: {len(LAGC)} LAGC themes consistent across hypr/dcol/kitty/waybar/rofi/rhun.")
