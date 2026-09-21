# Minimal accent discipline and theme cursor declaration

- Status: active
- Date: 2026-09-19
- Scope: LAGC Tech themes, Hyprland, Waybar, Rofi, Kitty, GTK/icons, cursor aliases, rofi-frosted.dcol
- Sources: live `theme.switch.sh`/`env-theme`/`hyq` behavior, WCAG measurements, dark-mode design research, owner acceptance on the live desktop

## Context

The owner asked for a stunning, eye-friendly, modern, solid, minimalist balance across the LAGC themes. Research consensus applied: one interactive accent family, attention-only secondary hues, quiet neutrals, off-black/off-white surfaces, and lifted/desaturated accents on dark themes to avoid the neon-on-velvet vibration.

## Evidence

- Cobalt `1B5CFF` on Midnight `061B2B` measures 3.35:1 and visibly vibrates on borders and ANSI blue; the lifted `4880FF` measures 4.84:1 and stays recognizably cobalt.
- `theme.switch.sh` writes both `default/index.theme` aliases from `$CURSOR_THEME`; with no theme-level declaration it fell back to `env-theme`'s `Bibata-Modern-Ice`, silently breaking the single `Future-cursors` identifier invariant. `hyq -Q '$CURSOR_SIZE[int]'` returns empty for every `$CURSOR_SIZE=` syntax, so `env-theme`'s `CURSOR_SIZE=24` always wins the GTK size hint (pre-existing upstream behavior, not a regression).
- `rofi-frosted.dcol` `main-br` now uses `wallbash_1xa3`: identical `B9D2DB` on Light, but `164B60` on Dark where `pry3`'s `103551` was nearly invisible.
- Geometry iterated live: 3/6 gaps were rejected as too airy and invisible island borders (hairline alpha 0.12) were rejected; the accepted state is `gaps_in 2`, `gaps_out 4` uniform, `rounding 10` (squircle 2.4), and island hairline `alpha(@main-fg, 0.20)`.

## Decision

Keep the accent grammar strict: cyan/cobalt is the only interactive family; Ember appears only where attention is semantic (kitty bell, locked groups, warn states); inactive borders are a single `rgba(58718280)` slate, never a gradient. Dark-theme thin accents (borders, ANSI blue) use the lifted `4880FF`; solid fills may keep `1B5CFF`. GTK stays neutral (`adw-gtk3`/`adw-gtk3-dark`) and icons stay `Fluent-teal-light`/`Fluent-teal-dark` so app interiors carry no foreign accent hue. Declare `$CURSOR_THEME=Future-cursors` and `$CURSOR_SIZE=42` in every LAGC `hypr.theme` so theme switches can never regress the cursor aliases again.

## Validation

- `hyde-shell theme.switch` Light and Dark: empty `hyprctl configerrors`, `gaps_out 4 4 4 4`, `rounding 10`, adw-gtk3 + Fluent-teal applied via gsettings.
- Both `index.theme` aliases read `Future-cursors` after a theme switch; generated `theme.rasi`, `kitty/theme.conf` and `waybar/theme.css` match the intended palettes.
- `./check.sh`, `./install.sh --dry-run --skip-packages`, `git diff --check` all pass; owner accepted the live result.

## Exit criteria

Revisit if the owner asks for a different accent balance or geometry, or if upstream fixes the `hyq` `[int]` query so `$CURSOR_SIZE` actually propagates (then verify the GTK cursor size hint matches 42).
