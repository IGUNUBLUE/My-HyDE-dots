# Stable Waybar height across mixed-scale displays

- Status: active
- Date: 2026-09-03
- Scope: Waybar, displays, fractional scaling
- Sources: live Waybar journal and Hyprland layer geometry

## Context

The historical custom layout requested 22 pixels, but GTK widget minimums could override that request after a theme refresh. When Waybar recalculated different minimums while focus crossed the 1.25-scale internal display and the 1.0-scale external display, its exclusive layer and tiled windows visibly moved. Raising the layout to 26 pixels prevented the resize but made the bar and window gap larger than the accepted pre-LAGC appearance.

## Evidence

- On 2026-09-09, Waybar initially logged `Requested height: 22 is less than the minimum height: 24 required by the modules`, followed by 25- and 26-pixel transient minimums while it reloaded the LAGC theme styles.
- A 25-pixel workaround appeared stable during reload and theme-cycle checks, but the required manual test reproduced the jump while moving the pointer between desktops.
- A controlled Material Sakura versus LAGC Tech Light comparison at 26 pixels produced identical layer geometry, margin and typography. Their `waybar.theme` files contain only palette variables, so LAGC colors were not the size cause.
- Waybar's documented minimal GTK CSS uses `min-height: 0`. Scoping that rule to the user-owned `#pill` and its descendants allowed the historical 22-pixel request on both outputs.
- A full install, Waybar reload, and Material Sakura → LAGC Tech Light cycle kept both live layers at exactly 22 pixels without minimum-height diagnostics. Real pointer crossing remains the final acceptance test because synthetic checks did not expose the earlier 25-pixel failure.

## Decision

Use `height: 22` in `dotfiles/.config/waybar/layouts/my-hyde.jsonc` together with the scoped `#pill` `min-height: 0` rule in `user-style.css`. Keep vertical margins symmetric and do not use negative margins or content offsets. Manual pointer crossing on every active mixed-scale output is mandatory; restore 26 pixels if any geometry jump, clipping or unusable click target appears.

## Validation

- Install through `./install.sh --skip-packages` so the live files are backed up.
- Reload Waybar through `hyde-shell waybar --set` using the `my-hyde` layout.
- Confirm Hyprland reports a 22-pixel Waybar layer on every active output and the journal has no minimum-height warning.
- Cycle Material Sakura and LAGC Tech Light, then repeatedly cross the pointer between outputs while watching the bar and tiled-window edge.
- Inspect workspace badges, icons, text and click targets for clipping before accepting the change.

## Exit criteria

Revisit if module content, font size, display scaling, or HyDE's generated base styles change. If the scoped minimum-size rule no longer preserves 22 pixels without clipping or pointer-triggered geometry changes, restore the known-safe 26-pixel height until a replacement passes the same live tests.
