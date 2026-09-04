# Polished Qt context menus

- Status: active
- Date: 2026-09-04
- Scope: Qt, Dolphin, Kvantum, HyDE themes

## Context

Dolphin context menus looked cramped and visually flat under Material Sakura. HyDE themes Qt applications through qt6ct and Kvantum, while Wallbash generates the active files under `~/.config/Kvantum/wallbash`.

## Evidence

The live session uses `QT_QPA_PLATFORMTHEME=qt6ct`, qt6ct selects `style=kvantum`, and the Material Sakura preset disabled menu icons with `iconless_menu=true`. The original preset also requested shadowless popups and did not define explicit menu-item text margins.

## Decision

Keep the upstream Material Sakura directory unchanged. The overlay derives `Material Sakura Polished` from that installed theme and replaces only its `kvantum/kvconfig.theme`. Enable menu icons, use moderate 4-pixel vertical and 8-pixel horizontal text margins, and permit Kvantum's popup shadow. Do not edit generated files under `~/.config/Kvantum/wallbash` directly.

## Validation

Select the variant through `hyde-shell theme.switch -q -s "Material Sakura Polished"`. Confirm the active state names that theme, qt6ct still selects Kvantum, the generated Wallbash kvconfig contains the four margins plus `iconless_menu=false`, and Dolphin shows the revised menu after reopening it.

## Exit criteria

Revisit this decision if HyDE adds a documented user-level Kvantum menu override that survives theme switching without deriving a theme, or if a future Kvantum release changes these keys.
