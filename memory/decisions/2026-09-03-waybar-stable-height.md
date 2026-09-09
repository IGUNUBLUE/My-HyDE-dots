# Stable Waybar height across mixed-scale displays

- Status: active
- Date: 2026-09-03
- Scope: Waybar, displays, fractional scaling
- Sources: live Waybar journal and Hyprland layer geometry

## Context

The custom layout can request a height below the minimum required by its modules. With the LAGC Tech global themes applied, a Waybar reload again recalculated its surfaces as focus crossed between the 1.25-scale internal display and the 1.0-scale external display, visibly moving the exclusive layer and tiled windows.

## Evidence

- On 2026-09-09, Waybar logged `Requested height: 22 is less than the minimum height: 24 required by the modules`, followed by 25- and 26-pixel minimums while it reloaded the LAGC theme styles.
- The same reload created 24-, 25-, and 26-pixel surfaces on both active outputs. A fixed 22-pixel request therefore could not remain stable with the current modules and styles.
- LAGC's `waybar.theme` contains only palette variables; it does not declare a font, size, padding, or height. The change in required minimum is caused by the active module/style combination after a global theme reload, not by a Kiro theme.

## Decision

Keep `height` fixed at 26 in `dotfiles/.config/waybar/layouts/my-hyde.jsonc`. This is the maximum observed module minimum across both active outputs, so the layer reserves a constant space rather than expanding while focus changes. It preserves the current readable text and click targets instead of shrinking them to retain the prior 22-pixel footprint.

## Validation

- Reload Waybar through `hyde-shell waybar --set` using the `my-hyde` layout.
- Confirm Hyprland reports a 26-pixel Waybar layer on every active output.
- Cross focus between outputs and confirm no new minimum-height warning or geometry change appears.

## Exit criteria

Revisit if module content, font size, display scaling, or HyDE's generated base styles change. Any replacement height must be tested on every active output and must produce no minimum-height warning while repeatedly crossing focus between monitors.
