#!/usr/bin/env bash
# Follows the active HyDE theme in the rhun editor: color theme and fonts.
#
# Theme: rhun reads [ui] theme from ~/.config/rhun/config (the value is the
# .theme file stem, its TH_id) and its inotify watcher reloads the config on
# IN_CLOSE_WRITE/IN_MOVED_TO of that file, so the colors change live. The four
# LAGC themes map 1:1; any other HyDE theme falls back to the LAGC Calm pair by
# light/dark mode.
#
# Fonts: [ui] font and [editor] font take a path to a TrueType (glyf) file, and
# rhun only reads the first face of a collection. The HyDE UI and monospace
# families ($FONT/$MONOSPACE_FONT from the theme's hypr.theme, else
# [desktop.ui] font/monospace_font in config.toml) are resolved through
# fontconfig; a face that is not first in its .ttc is copied out to
# ~/.config/rhun/fonts/. rhun loads fonts only at startup or from its Settings
# page, so a font change shows the next time rhun starts. A family that cannot
# be resolved to a usable glyf face leaves the current rhun value untouched.
set -Eeuo pipefail

conf_home="${XDG_CONFIG_HOME:-$HOME/.config}"
rhun_dir="$conf_home/rhun"
config="$rhun_dir/config"
marker="$rhun_dir/.wallbash-mode"
themes_dir="$rhun_dir/themes"
fonts_dir="$rhun_dir/fonts"

[[ -f $marker ]] || exit 0
mode=$(tr -d '[:space:]' < "$marker")
case "$mode" in
    dark|light) ;;
    *) exit 0 ;;
esac

# Resolve the active HyDE theme. color.set.sh exports HYDE_THEME and
# HYDE_THEME_DIR to every template command; fall back to the state file when
# the script is run by hand.
active_theme=${HYDE_THEME:-}
if [[ -z $active_theme && -n ${HYDE_THEME_DIR:-} ]]; then
    active_theme=$(basename -- "$HYDE_THEME_DIR")
fi
if [[ -z $active_theme ]]; then
    staterc="${XDG_STATE_HOME:-$HOME/.local/state}/hyde/staterc"
    [[ -f $staterc ]] && active_theme=$(awk -F'"' '/^HYDE_THEME=/{print $2}' "$staterc")
fi

case "$active_theme" in
    "LAGC Calm Dark")  want="lagc-calm-dark" ;;
    "LAGC Calm Light") want="lagc-calm-light" ;;
    "LAGC Tech Dark")  want="lagc-tech-dark" ;;
    "LAGC Tech Light") want="lagc-tech-light" ;;
    *) want="lagc-calm-$mode" ;;
esac
# Never select a theme that is not installed.
[[ -f "$themes_dir/$want.theme" ]] || want=""

# --- fonts -----------------------------------------------------------------

theme_dir=${HYDE_THEME_DIR:-"$conf_home/hyde/themes/$active_theme"}
hypr_theme="$theme_dir/hypr.theme"
hyde_config="$conf_home/hyde/config.toml"

# hypr_var NAME: $NAME=value from the active theme's hypr.theme, if declared.
hypr_var() {
    [[ -f $hypr_theme ]] || return 0
    sed -nE "s/^\\\$$1[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*\$/\\1/p" "$hypr_theme" | tail -n 1
}

# toml_ui KEY: KEY = "value" from the [desktop.ui] table of config.toml.
toml_ui() {
    [[ -f $hyde_config ]] || return 0
    awk -v key="$1" '
        /^[[:space:]]*\[/ { in_ui = ($0 ~ /^[[:space:]]*\[desktop\.ui\][[:space:]]*$/); next }
        in_ui && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            line = $0
            sub(/^[^=]*=[[:space:]]*/, "", line)
            sub(/[[:space:]]*(#.*)?$/, "", line)
            gsub(/^"|"$/, "", line)
            print line
            exit
        }' "$hyde_config"
}

# font_path FAMILY SLUG: print a rhun-loadable .ttf path for FAMILY, or nothing.
font_path() {
    local family=$1 slug=$2 matched file index format
    [[ -n $family ]] && command -v fc-match >/dev/null || return 0
    IFS=$'\t' read -r matched file index format < <(
        fc-match -f '%{family}\t%{file}\t%{index}\t%{fontformat}\n' "$family" 2>/dev/null) || return 0
    [[ $format == TrueType && -f $file ]] || return 0
    # fontconfig always answers; reject a fallback to an unrelated family.
    local requested=${family,,} name ok=false
    IFS=',' read -ra names <<< "${matched,,}"
    for name in "${names[@]}"; do
        [[ $requested == "$name" || $requested == "$name "* ]] && ok=true
    done
    $ok || return 0
    python3 - "$file" "${index:-0}" "$fonts_dir/$slug.ttf" <<'PY' || return 0
import os
import struct
import sys

source, index, target = sys.argv[1], int(sys.argv[2]), sys.argv[3]
data = open(source, "rb").read()
collection = data[:4] == b"ttcf"
offset = 0
if collection:
    count = struct.unpack(">I", data[8:12])[0]
    if index >= count:
        sys.exit(1)
    offset = struct.unpack(">%dI" % count, data[12:12 + 4 * count])[index]
version, tables = struct.unpack(">IH", data[offset:offset + 6])
records = [struct.unpack(">4sIII", data[offset + 12 + 16 * i:offset + 28 + 16 * i]) for i in range(tables)]
if version != 0x00010000 or not {b"glyf", b"loca", b"cmap"} <= {r[0] for r in records}:
    sys.exit(1)  # rhun only draws TrueType glyf outlines
if not collection or index == 0:
    print(source)  # rhun reads this file (or the first face) as is
    sys.exit(0)
# Copy the selected face out of the collection into a standalone sfnt.
header = data[offset:offset + 12]
directory, body = b"", b""
start = 12 + 16 * tables
for tag, checksum, table_offset, length in records:
    chunk = data[table_offset:table_offset + length]
    directory += struct.pack(">4sIII", tag, checksum, start + len(body), length)
    body += chunk + b"\0" * (-len(chunk) % 4)
os.makedirs(os.path.dirname(target), exist_ok=True)
temporary = target + ".tmp"
with open(temporary, "wb") as handle:
    handle.write(header + directory + body)
os.replace(temporary, target)
print(target)
PY
}

ui_family=$(hypr_var FONT)
[[ -n $ui_family ]] || ui_family=$(toml_ui font)
mono_family=$(hypr_var MONOSPACE_FONT)
[[ -n $mono_family ]] || mono_family=$(toml_ui monospace_font)
ui_font=$(font_path "$ui_family" ui)
editor_font=$(font_path "$mono_family" editor)

# --- write ~/.config/rhun/config ---------------------------------------------

mkdir -p "$rhun_dir"
[[ -f $config ]] || : > "$config"

# set_key FILE SECTION KEY VALUE: replace or add KEY in [SECTION], keep the rest.
set_key() {
    local file=$1 section=$2 key=$3 value=$4 tmp="$1.edit"
    awk -v section="$section" -v key="$key" -v value="$value" '
        function emit() { print key " = " value; wrote = 1 }
        /^[[:space:]]*\[/ {
            if (in_sec && !wrote) emit()
            in_sec = ($0 ~ "^[[:space:]]*\\[" section "\\][[:space:]]*$")
            if (in_sec) seen = 1
            print
            next
        }
        in_sec && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            if (!wrote) emit()
            next
        }
        { print }
        END {
            if (in_sec && !wrote) emit()
            if (!seen) { print "[" section "]"; emit() }
        }' "$file" > "$tmp" && mv -f "$tmp" "$file"
}

work="$config.tmp.$$"
trap 'rm -f -- "$work" "$work.edit"' EXIT
cp -- "$config" "$work"
[[ -n $want ]] && set_key "$work" ui theme "$want"
[[ -n $ui_font ]] && set_key "$work" ui font "$ui_font"
[[ -n $editor_font ]] && set_key "$work" editor font "$editor_font"

# One atomic replace, and none at all when nothing changed, so rhun reloads
# exactly once per real change.
if cmp -s -- "$config" "$work"; then
    exit 0
fi
mv -f -- "$work" "$config"
exit 0
