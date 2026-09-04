# Polished Qt context menus

- Status: superseded
- Date: 2026-09-04
- Scope: Qt, Dolphin, Kvantum, HyDE themes

## Context

Dolphin context menus looked cramped and visually flat under Material Sakura. HyDE themes Qt applications through qt6ct and Kvantum, while Wallbash generates the active files under `~/.config/Kvantum/wallbash`.

## Evidence

The live session uses `QT_QPA_PLATFORMTHEME=qt6ct`, qt6ct selects `style=kvantum`, and the Material Sakura preset disabled menu icons with `iconless_menu=true`. The original preset also requested shadowless popups and did not define explicit menu-item text margins.

## Decision

Superseded by the owner\x27s request for all themes: use `qt-menu.ini` and the documented Wallbash post-render callback. The installer derives a user kvconfig.dcol from installed upstream, preserving its body and color placeholders. Theme-mode rendering also uses this callback, as verified in color.set.sh. The callback changes only menu keys in generated output. Theme directories are no longer copied or selected by installation. Reapply after upstream updates to refresh the user template.

Previous decision:

Keep the upstream Material Sakura directory unchanged. The overlay derives `Material Sakura Polished` from that installed theme and replaces only its `kvantum/kvconfig.theme`. Enable menu icons, use moderate 4-pixel vertical and 8-pixel horizontal text margins, and permit Kvantum's popup shadow. Do not edit generated files under `~/.config/Kvantum/wallbash` directly.

## Validation

Select the variant through `hyde-shell theme.switch -q -s "Material Sakura Polished"`. Confirm the active state names that theme, qt6ct still selects Kvantum, the generated Wallbash kvconfig contains the four margins plus `iconless_menu=false`, and Dolphin shows the revised menu after reopening it.

## Exit criteria

Revisit this decision if HyDE adds a documented user-level Kvantum menu override that survives theme switching without deriving a theme, or if a future Kvantum release changes these keys.
