# Waybar hangs without bars after overlapping reloads

- Date: 2026-10-03
- Status: active
- Sources: user report ("se perdió el waybar del escritorio") after a live theme-test session with ~40 theme switches; `journalctl --user -u hyde-Hyprland-bar.service`; `~/.local/lib/hyde/waybar.py` (`restart_waybar` → `systemctl --user kill -s SIGUSR2`); Waybar v0.15.0; reproduction scripts run on the live session.

## Context

After many theme switches the Waybar bar vanished from both monitors. The `waybar` process (unit `hyde-Hyprland-bar.service`) was still running and sleeping, but `hyprctl layers` listed no `waybar` layer surface on any output. Its log stopped after `Reloading...` / `Using CSS file ...`, with no `Bar configured` line, and later SIGUSR2 signals were accepted without effect.

## Evidence

- HyDE reloads Waybar with one SIGUSR2 per theme switch (`waybar.py` `restart_waybar`), and `systemctl kill` also delivers it to Waybar's helper processes (`bwrap`/`glycin-*` image loaders, `swaync-client`).
- Reproduced on the live session: two SIGUSR2 0.66 s apart hung Waybar on the 2nd iteration; a style-file replace followed by SIGUSR2 0.34 s later hung it on the 16th. In each case the process stayed alive with zero bars until `systemctl --user restart hyde-Hyprland-bar.service`.
- Replacing `theme.css`, `style.css` or `user-style.css` on their own triggered no reload, so `reload_style_on_change` is not the trigger in normal use; overlapping SIGUSR2 reloads are. A single reload per switch never hung across 600+ switch checks.
- Upstream bug class: Waybar issues #1381 and #3126 report bars disappearing or reloads failing after SIGUSR2; no fix applies to 0.15.0 here.

## Decision

- Waybar and HyDE's `waybar.py` stay unpatched (upstream-managed). The overlay adds a Wallbash `always/` hook, `waybar-guard.dcol` + `scripts/my-hyde-waybar-guard.sh`, that runs after every theme switch: it waits 2 s, then for 15 s after the latest switch checks that every monitor in `hyprctl monitors` has a `waybar` layer, and restarts the unit once if a monitor has been without one for 4 s. Rapid switches re-arm a single guard (flock + re-arm stamp), and an inactive unit (Waybar stopped by the user) is never started.
- Assumes the active layout puts a bar on every output (`"output": ["*"]` in `my-hyde.jsonc`); a layout limited to some outputs would cause one restart per switch and needs the guard adjusted.

## Validation

- `tests/hooks.py` (fake `hyprctl`/`systemctl`): restart after bars vanish, no restart on a normal sub-grace gap, restart when one monitor lacks a bar, no action on an inactive unit, at most one restart per run. Red before the script existed, green after.
- No false restarts: six normal switches (`tests/live-theme.sh`, 156/156) and three rounds of six switches one second apart left the guard idle.
- Correction (same day): the guard's live restart path is **not** verified. Every live recovery first credited to it was systemd's own `Restart=always` (set by `waybar.py --watch`) after a Waybar crash: six coredumps between 13:35 and 13:39, all during deliberate overlapping-SIGUSR2 stress and 1 s rapid switching — SIGSEGV in `Gtk::Widget::set_visible` from the GLib main loop, and SIGABRT from a GLib critical. The instance systemd started at 13:39 registered its layer surfaces (`hyprctl layers` showed 26 px bars, the log showed `Bar configured` twice for HDMI-A-5) but drew nothing; the user saw no bar. The guard cannot see that state because the layers exist. `systemctl --user restart hyde-Hyprland-bar.service` fixed it, and screenshots then showed the bar on both monitors through further normal switches with no new coredump.
- `tests/live-theme.sh` asserts a Waybar layer on every monitor plus a screenshot heuristic: at least 35 % of each bar strip within 6 % of `main-bg` (visible bars measured 0.51–0.63, the invisible bar 0.19); monitors showing a fullscreen window are skipped.

## Exit criteria

- Remove the guard when a Waybar release survives overlapping SIGUSR2 reloads (rerun the two-signals-0.66 s reproduction) or when HyDE serializes its reloads.
- Do not stress-test Waybar reloads on the user's live session again without warning: overlapping reloads crash or blank the bar. Use a separate Waybar instance with its own config if the guard's restart path must be verified live.
