# Stable Waybar height across mixed-scale displays

- Status: active
- Date: 2026-09-03
- Scope: Waybar, displays, fractional scaling
- Sources: live Waybar journal and Hyprland layer geometry

## Context

The custom layout can request a height below the minimum required by its modules. With the LAGC Tech global themes applied, a Waybar reload again recalculated its surfaces as focus crossed between the 1.25-scale internal display and the 1.0-scale external display, visibly moving the exclusive layer and tiled windows.

## Evidence

- On 2026-09-09, Waybar initially logged `Requested height: 22 is less than the minimum height: 24 required by the modules`, followed by 25- and 26-pixel transient minimums while it reloaded the LAGC theme styles.
- A controlled 25-pixel retest appeared stable during Waybar reload, LAGC Tech Light refresh, and a Dark → Light cycle: both outputs reported 25 pixels and the journal showed no minimum-height diagnostics.
- The required manual test then reproduced the original jump while moving the pointer between desktops. Synthetic reload and theme-cycle checks therefore cannot establish cross-display stability at 25 pixels.
- LAGC's `waybar.theme` contains only palette variables; it does not declare a font, size, padding, or height. The change in required minimum is caused by the active module/style combination after a global theme reload, not by a Kiro theme.

## Decision

Keep `height` fixed at 26 in `dotfiles/.config/waybar/layouts/my-hyde.jsonc`. This is the smallest height that has not reproduced the focus-crossing jump in real use with the current modules, styles, and mixed-scale outputs. Do not lower it based only on reload logs or static layer geometry; manual pointer crossing is mandatory.

## Validation

- Reload Waybar through `hyde-shell waybar --set` using the `my-hyde` layout.
- Confirm Hyprland reports a 26-pixel Waybar layer on every active output.
- Cross focus between outputs and confirm no new minimum-height warning or geometry change appears.

## Exit criteria

Revisit if module content, font size, display scaling, or HyDE's generated base styles change. Any replacement height must be tested on every active output and must produce no minimum-height warning while repeatedly crossing focus between monitors.
