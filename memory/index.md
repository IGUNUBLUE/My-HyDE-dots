# Memory index

Read active and monitoring entries relevant to a component before modifying it.

| Status | Scope | Memory | Summary |
| --- | --- | --- | --- |
| active | Hypridle, Hyprlock, NVIDIA, displays | [Hyprlock input stall mitigation](incidents/2026-09-02-hyprlock-input-stall.md) | Keep automatic lock, DPMS-off and suspend disabled until a controlled dual-monitor unlock test succeeds on a fixed version. |
| active | Waybar, displays, fractional scaling | [Stable Waybar height](decisions/2026-09-03-waybar-stable-height.md) | Keep the bar at 26 logical pixels to prevent focus-triggered resizing across mixed-scale displays. |
| superseded | Qt, Dolphin, Kvantum, themes | [Polished Qt context menus](decisions/2026-09-04-polished-qt-context-menus.md) | Theme-specific variant replaced by global preferences. |
| active | Qt, Kvantum, Wallbash | [Global Qt menus](decisions/2026-09-04-global-qt-menus.md) | Apply qt-menu.ini through the documented Wallbash callback across themes. |
