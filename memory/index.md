# Memory index

Read active and monitoring entries relevant to a component before modifying it.

| Status | Scope | Memory | Summary |
| --- | --- | --- | --- |
| active | Hypridle, Hyprlock, NVIDIA, displays | [Hyprlock input stall mitigation](incidents/2026-09-02-hyprlock-input-stall.md) | Keep automatic lock, DPMS-off and suspend disabled until a controlled dual-monitor unlock test succeeds on a fixed version. |
| active | Waybar, displays, fractional scaling | [Stable Waybar height](decisions/2026-09-03-waybar-stable-height.md) | Keep the bar at 22 logical pixels to prevent focus-triggered resizing across mixed-scale displays. |
