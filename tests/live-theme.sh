#!/usr/bin/env bash
# Live end-to-end theme test. Needs a running HyDE/Hyprland session.
#
# Cycles the LAGC themes with `hydectl theme set` and, after every switch,
# asserts what apps actually receive: gsettings, the xdg-desktop-portal
# colour scheme, GTK3/GTK4/libadwaita runtime state, gtk-3.0/settings.ini,
# xsettingsd, Wallbash-Gtk, kitty, Waybar, Rofi, Qt and rhun. Browsers are
# opened once with throwaway profiles (Chrome/Brave in "Use GTK" mode,
# Firefox default) and kept open across switches, so a browser that keeps the
# previous theme fails the test. The theme active before the run is restored.
#
#   tests/live-theme.sh                 # all four LAGC themes, all browsers
#   BROWSERS="firefox" tests/live-theme.sh
#   SEQ="LAGC Calm Dark|LAGC Tech Dark" tests/live-theme.sh
#
# Browser windows appear briefly on the focused workspace; your own browser
# profiles are never opened or modified.
set -uo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
themes_dir="$repo_dir/dotfiles/.config/hyde/themes"
cfg=${XDG_CONFIG_HOME:-$HOME/.config}
settle=${SETTLE:-3}
IFS='|' read -ra seq <<< "${SEQ:-LAGC Calm Dark|LAGC Tech Dark|LAGC Calm Light|LAGC Tech Light|LAGC Calm Dark}"
read -ra browsers <<< "${BROWSERS-chrome brave firefox}"
work=$(mktemp -d)
pass=0 fail=0
declare -A pids profiles

for tool in hydectl hyprctl gsettings gdbus grim magick python3; do
    command -v "$tool" >/dev/null || { echo "SKIP: $tool not found"; exit 2; }
done
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { echo "SKIP: no Hyprland session"; exit 2; }

ok() { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
expect() { [[ $2 == "$3" ]] && ok "$1 = $2" || bad "$1 = '$2', expected '$3'"; }
dcol() { sed -nE "s/^$2=\"([^\"]*)\"/\\1/p" "$themes_dir/$1/theme.dcol"; }
hvar() { sed -nE "s/^\\\$$2[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*\$/\\1/p" "$themes_dir/$1/hypr.theme" | tail -n 1; }
gs() { gsettings get org.gnome.desktop.interface "$1" | tr -d "'"; }
ini() { awk -F= -v k="$2" '$1==k{gsub(/"/,"",$2);print $2;exit}' "$1" 2>/dev/null; }
upper() { tr '[:lower:]' '[:upper:]'; }

# family COLOR: dark|light by luminance, warm|cool by red vs blue; near-grey
# (|R-B| < 6, e.g. adw-gtk3's #FAFAFB/#EBEBED) is "neutral" and never matches.
family() {
    local hex=${1#\#} r g b
    r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
    local lum=$(( (299 * r + 587 * g + 114 * b) / 1000 )) tint
    if (( r - b >= 6 )); then tint=warm; elif (( b - r >= 6 )); then tint=cool; else tint=neutral; fi
    printf '%s-%s' "$( ((lum < 128)) && echo dark || echo light)" "$tint"
}
expected_family() { # Calm is warm, Tech is cool
    local mode; mode=$(dcol "$1" dcol_mode)
    [[ $1 == *Calm* ]] && echo "$mode-warm" || echo "$mode-cool"
}

page="$work/probe.html"
cat > "$page" <<'EOF'
<!doctype html><title>THEMEPROBE</title><style>html,body{margin:0;height:100%;background:#00ff00}@media (prefers-color-scheme:dark){html,body{background:#ff0000}}</style>
EOF

open_browser() {
    local name=$1 profile="$work/$1"
    mkdir -p "$profile"
    case $name in
        chrome|brave)
            local bin=google-chrome-stable; [[ $name == brave ]] && bin=brave
            command -v "$bin" >/dev/null || { echo "  skip  $name not installed"; return; }
            mkdir -p "$profile/Default"; touch "$profile/First Run"
            printf '{"extensions":{"theme":{"system_theme":1}},"browser":{"has_seen_welcome_page":true}}' > "$profile/Default/Preferences"
            "$bin" --user-data-dir="$profile" --no-first-run --no-default-browser-check --disable-sync \
                --new-window "file://$page" >/dev/null 2>&1 &
            ;;
        firefox)
            command -v firefox >/dev/null || { echo "  skip  firefox not installed"; return; }
            printf 'user_pref("browser.shell.checkDefaultBrowser", false);\nuser_pref("browser.aboutwelcome.enabled", false);\nuser_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);\n' > "$profile/user.js"
            firefox --new-instance --no-remote --profile "$profile" "file://$page" >/dev/null 2>&1 &
            ;;
    esac
    pids[$name]=$! profiles[$name]=$profile
}
browser_class() { case $1 in chrome) echo google-chrome ;; brave) echo brave-browser ;; firefox) echo firefox ;; esac; }
sample_browser() { # name -> "TABBAR CONTENT"
    local geo png="$work/$1.png"
    geo=$(hyprctl clients -j | python3 -c '
import json, sys
for c in json.load(sys.stdin):
    if c["class"] == sys.argv[1] and "THEMEPROBE" in c["title"]:
        x, y = c["at"]; w, h = c["size"]; print("%d,%d %dx%d" % (x, y, w, h)); break' "$(browser_class "$1")")
    [[ -n $geo ]] || { echo "none none"; return; }
    grim -g "$geo" "$png" 2>/dev/null || { echo "none none"; return; }
    local w h
    w=$(magick identify -format %w "$png"); h=$(magick identify -format %h "$png")
    printf '%s %s\n' "$(magick "$png" -crop 1x1+$((w / 2))+15 -format '%[hex:p{0,0}]' info: | cut -c1-6)" \
        "$(magick "$png" -crop 1x1+40+$((h - 40)) -format '%[hex:p{0,0}]' info: | cut -c1-6)"
}
cleanup() {
    local name
    for name in "${!pids[@]}"; do kill "${pids[$name]}" 2>/dev/null; done
    sleep 1
    for name in "${!profiles[@]}"; do pkill -f -- "${profiles[$name]}" 2>/dev/null; done
    if [[ -n ${original:-} ]]; then
        hydectl theme set "$original" >/dev/null 2>&1
        echo "restored theme: $original"
    fi
    rm -rf "$work"
}
trap cleanup EXIT

original=$(awk -F'"' '/^HYDE_THEME=/{print $2}' "${XDG_STATE_HOME:-$HOME/.local/state}/hyde/staterc")
for b in "${browsers[@]}"; do open_browser "$b"; done
sleep 6

for theme in "${seq[@]}"; do
    hydectl theme set "$theme" >/dev/null 2>&1 || bad "hydectl theme set '$theme' failed"
    # Wait until the switch has settled instead of a fixed sleep: gtk-theme
    # back on the real name (the refresh hook briefly sets a placeholder),
    # both gtk-dark.css copies current, and a Waybar layer on every monitor.
    # A real hang still fails because it outlasts the 20 s limit.
    want_gtk=$(hvar "$theme" GTK_THEME)
    gtk_dir=${XDG_DATA_HOME:-$HOME/.local/share}/themes/$want_gtk
    deadline=$(( $(date +%s) + ${SETTLE_MAX:-20} ))
    sleep "$settle"
    while (( $(date +%s) < deadline )); do
        [[ $(gs gtk-theme) == "$want_gtk" ]] &&
            cmp -s "$gtk_dir/gtk-3.0/gtk.css" "$gtk_dir/gtk-3.0/gtk-dark.css" &&
            cmp -s "$gtk_dir/gtk-4.0/gtk.css" "$gtk_dir/gtk-4.0/gtk-dark.css" &&
            hyprctl layers -j | python3 -c '
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if all(any(l["namespace"] == "waybar" for ls in v["levels"].values() for l in ls) for v in d.values()) else 1)' &&
            break
        sleep 0.5
    done
    sleep "${REPAINT:-1.5}"   # let GTK clients repaint after the last re-emit
    mode=$(dcol "$theme" dcol_mode); base=$(dcol "$theme" dcol_pry1 | upper)
    portal_want=1; [[ $mode == light ]] && portal_want=2
    echo "== $theme ($mode, #$base)"

    expect "staterc HYDE_THEME" "$(awk -F'"' '/^HYDE_THEME=/{print $2}' "${XDG_STATE_HOME:-$HOME/.local/state}/hyde/staterc")" "$theme"
    expect "gsettings color-scheme" "$(gs color-scheme)" "prefer-$mode"
    expect "gsettings gtk-theme" "$(gs gtk-theme)" "$(hvar "$theme" GTK_THEME)"
    expect "gsettings icon-theme" "$(gs icon-theme)" "$(hvar "$theme" ICON_THEME)"
    expect "portal color-scheme" "$(gdbus call --session --dest org.freedesktop.portal.Desktop \
        --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.ReadOne \
        org.freedesktop.appearance color-scheme 2>/dev/null | grep -oE 'uint32 [0-9]+' | awk '{print $2}')" "$portal_want"
    expect "gtk-3.0 prefer-dark" "$(ini "$cfg/gtk-3.0/settings.ini" gtk-application-prefer-dark-theme)" "$([[ $mode == dark ]] && echo 1 || echo 0)"
    expect "gtk-3.0 theme" "$(ini "$cfg/gtk-3.0/settings.ini" gtk-theme-name)" "$(hvar "$theme" GTK_THEME)"
    expect "xsettingsd running" "$(systemctl --user is-active xsettingsd.service)" active
    gtk_dir=${XDG_DATA_HOME:-$HOME/.local/share}/themes/$(hvar "$theme" GTK_THEME)
    expect "Wallbash-Gtk bg" "$(grep -oE '@define-color theme_bg_color #[0-9A-Fa-f]{6}' "$gtk_dir/gtk-3.0/gtk.css" | head -1 | awk '{print $3}' | upper)" "#$base"
    for v in gtk-3.0 gtk-4.0; do
        cmp -s "$gtk_dir/$v/gtk.css" "$gtk_dir/$v/gtk-dark.css" && ok "$v gtk-dark.css current" || bad "$v gtk-dark.css stale"
    done
    expect "kitty background" "$(awk '$1=="background"{print $2;exit}' "$cfg/kitty/theme.conf" | upper)" "#$base"
    expect "waybar main-bg" "$(grep -oE '@define-color main-bg #[0-9A-Fa-f]{6}' "$cfg/waybar/theme.css" | awk '{print $3}' | upper)" "#$base"
    expect "rofi main-bg" "$(grep -oE 'main-bg:[[:space:]]+#[0-9A-Fa-f]{6}' "$cfg/rofi/theme.rasi" | head -1 | awk '{print $2}' | upper)" "#$base"
    expect "qt6ct icons" "$(ini "$cfg/qt6ct/qt6ct.conf" icon_theme)" "$(hvar "$theme" ICON_THEME)"
    # Waybar must still have a bar on every monitor: a reload that hangs keeps
    # the process alive with no layer surface, which looks like a lost bar.
    bars=$(hyprctl layers -j | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(sum(any(l["namespace"] == "waybar" for ls in v["levels"].values() for l in ls) for v in d.values()), len(d))')
    expect "waybar bars on monitors" "${bars% *}" "${bars#* }"
    # A bar can be mapped yet draw nothing (seen after a Waybar crash/restart):
    # require Waybar's main-bg on a share of each visible bar strip.
    wb_bg=$(grep -oE '@define-color main-bg #[0-9A-Fa-f]{6}' "$cfg/waybar/theme.css" | awk '{print $3}')
    while read -r mon pos size fs; do
        geo="$pos $size"
        [[ $fs == True ]] && { ok "waybar on $mon not checked (fullscreen window)"; continue; }
        grim -g "$geo" "$work/bar-$mon.png" 2>/dev/null || { bad "waybar strip capture failed on $mon"; continue; }
        share=$(LC_NUMERIC=C magick "$work/bar-$mon.png" -fuzz 6% -fill black -opaque "$wb_bg" \
            -fill white +opaque black -negate -format '%[fx:mean]' info:)
        # A bar can be blank for a moment while it repaints after a reload;
        # only a bar still blank after 10 s counts as lost.
        for _ in $(seq 20); do
            LC_NUMERIC=C awk -v s="$share" 'BEGIN{exit !(s >= 0.35)}' && break
            sleep 0.5
            grim -g "$geo" "$work/bar-$mon.png" 2>/dev/null
            share=$(LC_NUMERIC=C magick "$work/bar-$mon.png" -fuzz 6% -fill black -opaque "$wb_bg" \
                -fill white +opaque black -negate -format '%[fx:mean]' info:)
        done
        LC_NUMERIC=C awk -v s="$share" 'BEGIN{exit !(s >= 0.35)}' \
            && ok "waybar visible on $mon (main-bg share $share)" \
            || bad "waybar not drawn on $mon (main-bg share $share < 0.35)"
    done < <(hyprctl monitors -j | python3 -c '
import json, subprocess, sys
clients = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True).stdout)
for m in json.load(sys.stdin):
    ws = m["activeWorkspace"]["id"]
    fs = any(c["workspace"]["id"] == ws and c["fullscreen"] for c in clients)
    print(m["name"], "%d,%d" % (m["x"], m["y"] + 4), "%dx20" % int(m["width"] / m["scale"]), fs)')
    if [[ -f $cfg/rhun/config ]]; then
        expect "rhun theme" "$(awk -F' = ' '$1=="theme"{print $2;exit}' "$cfg/rhun/config")" "$(tr '[:upper:] ' '[:lower:]-' <<< "$theme")"
    fi

    runtime=$(python3 - 2>/dev/null <<'PY'
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
s = Gtk.Settings.get_default(); w = Gtk.Window()
found, c = w.get_style_context().lookup_color("theme_bg_color")
print("%d %02X%02X%02X" % (s.props.gtk_application_prefer_dark_theme,
      int(c.red * 255), int(c.green * 255), int(c.blue * 255)))
PY
)
    expect "GTK3 client prefer-dark" "${runtime%% *}" "$([[ $mode == dark ]] && echo 1 || echo 0)"
    expect "GTK3 client bg" "#${runtime##* }" "#$base"
    adw=$(python3 - 2>/dev/null <<'PY'
import gi
gi.require_version("Adw", "1")
from gi.repository import Adw
Adw.init(); print("dark" if Adw.StyleManager.get_default().get_dark() else "light")
PY
)
    [[ -n $adw ]] && expect "libadwaita client" "$adw" "$mode"

    want_family=$(expected_family "$theme")
    for b in "${!pids[@]}"; do
        read -r tabbar content < <(sample_browser "$b")
        if [[ $tabbar == none ]]; then bad "$b window not found"; continue; fi
        case $content in FF0000) content=dark ;; 00FF00) content=light ;; *) content="?#$content" ;; esac
        expect "$b page prefers-color-scheme" "$content" "$mode"
        got=$(family "$tabbar")
        [[ $got == "$want_family" ]] && ok "$b toolbar #$tabbar is $got" \
            || bad "$b toolbar #$tabbar is $got, expected $want_family (stale theme?)"
    done
done

echo
echo "live theme test: $pass passed, $fail failed"
((fail == 0))
