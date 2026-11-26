# Investigate the 26-pixel bar on a fresh Waybar 0.16 installation

Status: ready-for-agent
Blocked by: none

## Reproduction

On the Arch/HyDE VM described in `../validation.md`, apply the published overlay
and run `BROWSERS=firefox tests/live-theme.sh` in its graphical session. The
complete run reports 135 passes and five failures, all actual bar heights of 26
instead of the expected 24. Hyprland is 0.57.2 and Waybar is 0.16.0.

The font configuration is already 13 px / 9 px and the scoped minimum-height
override is installed. Neither a reboot, bar restart, LAGC switch nor temporary
Full HD mode fixes the height. Separate temporary layouts measured the sensor
group at 26, the other groups at 24, and each individual sensor module at 24.
The incomplete pair probe and unsuccessful font-weight trial establish no cause.
Missing CPU frequency/temperature data also exposes malformed JSON from the
upstream CPU-info script in this VM; distinguish that from the height cause.

## Constraints and acceptance

Read the active Waybar height/reload memories first. Preserve 13 px / 9 px and
the `my-hyde` layout. Use user-owned overrides and supported HyDE commands; keep
upstream styles and scripts untouched. Keep labels, click targets and spacing
usable. Retain 26 as the known-safe rollback rather than shrinking blindly.

Require a reproducible, causal height fix and the full live theme cycle. Any
change to height/minimum-height also needs real pointer crossing and visual
acceptance on every physical output before claiming the owner's desktop is
verified. This finding is separate from the delivered installer regressions.
