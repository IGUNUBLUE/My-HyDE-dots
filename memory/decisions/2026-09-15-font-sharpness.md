# Sharp LCD font baseline

- Status: active
- Date: 2026-09-15
- Scope: fontconfig, HyDE fonts, displays
- Sources: `fc-match -v "Noto Sans"` before/after on live system; ArchWiki Font configuration (hintstyle default hintslight, rgba rgb, lcdfilter lcddefault, Chromium stem-darkening note); Hyprland XWayland docs (force_zero_scaling); `hyprctl monitors all` (eDP-1 ~143 DPI at 1.25, LG 1080p ~81 DPI at 1.0)

## Context

Text on the external LG 1080p monitor looked blurry. The system had no `10-sub-pixel-rgb.conf` preset enabled and the user `fonts.conf` set only antialias/hinting/hintstyle, so `fc-match` showed no `rgba` value. HyDE requested `font_hinting="full"` while fontconfig used `hintslight`.

## Evidence

- Before: `fc-match -v "Noto Sans"` showed `hintstyle: 1`, `hinting: True`, `lcdfilter: 1`, no `rgba` line.
- After candidate user config: same query shows `rgba: 1` with unchanged hintslight path.
- External panel is физически ~81 DPI, so it cannot become retina; the fix only restores proper subpixel rendering.
- Native Wayland clients stay sharp; XWayland clients (observed: VirtualBox) remain limited by XWayland scaling.

## Decision

Keep the user-owned baseline in `dotfiles/.config/fontconfig/fonts.conf`: antialias + hintslight + rgba rgb + lcddefault, no embedded bitmaps except Noto Color Emoji, preserving synthetic oblique/embolden. Keep HyDE `font_hinting` at `slight` to match fontconfig. Do not edit `/etc/fonts`.

## Validation

- `python -c "import xml.etree.ElementTree"` parses the tracked `fonts.conf`.
- `fc-match -v "Noto Sans" | grep -E "rgba|lcdfilter|hintstyle"` shows `rgba: 1`, `lcdfilter: 1`, `hintstyle: 1`.
- `./check.sh` and `./install.sh --dry-run --skip-packages` pass.
- Live acceptance still requires opening a new app on the LG panel and comparing text.

## Exit criteria

Resolve only after text on the LG panel is accepted in a new native Wayland app, or supersede with a documented alternative (for example stem-darkening env, larger UI font, or integer-scale layout).
