#!/usr/bin/env bash
# Restarts Waybar when a theme-switch reload leaves it without bars.
#
# HyDE reloads Waybar with SIGUSR2 on every theme switch. Waybar 0.15 can hang
# when two reloads overlap (reproduced with two SIGUSR2 0.66 s apart, and with
# a style reload followed by SIGUSR2): the process stays alive but no bar layer
# surface remains, so the bar is simply gone until a restart. After each switch
# this guard watches the bars for a short window and restarts the unit once if
# some monitor has had no Waybar bar for longer than a normal reload gap. A
# Waybar the user stopped (inactive unit) is left alone. Rapid switches re-arm
# the single running guard instead of starting more of them.
set -Eeuo pipefail

unit=hyde-Hyprland-bar.service
delay=${MY_HYDE_WAYBAR_GUARD_DELAY:-2}        # let HyDE's reload signal land
window=${MY_HYDE_WAYBAR_GUARD_WINDOW:-15}     # seconds watched after the last switch
grace=${MY_HYDE_WAYBAR_GUARD_GRACE:-4}        # longest acceptable bar gap
interval=${MY_HYDE_WAYBAR_GUARD_INTERVAL:-0.5}
run_dir="${XDG_RUNTIME_DIR:-/tmp}/hyde"
lock="$run_dir/waybar-guard.lock"
rearm="$run_dir/waybar-guard.rearm"

command -v hyprctl >/dev/null && command -v systemctl >/dev/null || exit 0
mkdir -p "$run_dir"
touch "$rearm"
exec 9>"$lock"
flock -n 9 || exit 0   # a guard is already watching; touching $rearm extends it

now() { date +%s%N; }
ns() { python3 -c "import sys;print(int(float(sys.argv[1])*1e9))" "$1"; }

# missing_bars: number of monitors without a waybar layer surface.
missing_bars() {
    python3 - "$(hyprctl monitors -j 2>/dev/null)" "$(hyprctl layers -j 2>/dev/null)" <<'PY'
import json, sys
try:
    monitors = {m["name"] for m in json.loads(sys.argv[1])}
    layers = json.loads(sys.argv[2])
except (ValueError, KeyError):
    print(0); sys.exit()
with_bar = {name for name, value in layers.items()
            if any(l.get("namespace") == "waybar" for ls in value.get("levels", {}).values() for l in ls)}
print(len(monitors - with_bar))
PY
}

sleep "$delay"
window_ns=$(ns "$window") grace_ns=$(ns "$grace")
gap_start=""
while :; do
    systemctl --user is-active --quiet "$unit" || exit 0
    t=$(now)
    last_switch=$(( $(stat -c %Y "$rearm") * 1000000000 ))
    (( t - last_switch > window_ns )) && [[ -z $gap_start ]] && exit 0
    if (( $(missing_bars) > 0 )); then
        gap_start=${gap_start:-$t}
        if (( t - gap_start >= grace_ns )); then
            systemctl --user restart "$unit"
            exit 0
        fi
    else
        gap_start=""
        (( t - last_switch > window_ns )) && exit 0
    fi
    sleep "$interval"
done
