# Stable Waybar height across mixed-scale displays

- Status: active
- Date: 2026-09-03
- Scope: Waybar, displays, fractional scaling
- Sources: live Waybar journal and Hyprland layer geometry

## Context

The custom layout requested a height below the minimum required by its modules. When pointer focus crossed between the 1.25-scale internal display and the 1.0-scale external display, Waybar recalculated its surfaces and visibly oscillated between 20, 21 and 22 logical pixels.

## Evidence

- Waybar logged that a requested 20-pixel surface was smaller than the 21- or 22-pixel minimum required by its modules.
- Hyprland layer geometry and Waybar logs showed temporary 20-, 21- and 22-pixel surfaces on both outputs.
- The layout's former `height` value was only a minimum; it could not force content into a smaller surface.

## Decision

Keep `height` fixed at 22 in `dotfiles/.config/waybar/layouts/my-hyde.jsonc`. This matches the observed module minimum and prevents focus-triggered resizing without shrinking text or icon hit targets.

## Validation

- Reload Waybar through `hyde-shell waybar --set` using the `my-hyde` layout.
- Confirm Hyprland reports a 22-pixel Waybar layer on every active output.
- Cross focus between outputs and confirm no new minimum-height warning or geometry change appears.

## Exit criteria

Change this value only when module content, font size, or display scaling changes. Any replacement height must be tested on every active output and must produce no minimum-height warning while repeatedly crossing focus between monitors.
