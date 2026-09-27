#!/usr/bin/env bash
# Splices the active HyDE kitty ANSI palette into the generated Oh My Pi theme
# and selects it. Semantic ANSI colors are not wallbash variables, so the .dcol
# carries @ANSIn@ markers resolved here; @MIX_n@ markers become ANSI n tinted
# 18% over the theme background for tool result panels. The same theme file is
# pinned to both config.yml slots (theme.dark/theme.light): wallbash only knows
# the active palette, and OMP picks a slot from terminal luminance on its own.
# OMP watches the active custom theme file and hot-reloads it, so running TUIs
# pick up regenerated colors without a signal or restart.
set -Eeuo pipefail

omp_dir="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
theme_file="$omp_dir/themes/hyde-wallbash.json"
config="$omp_dir/config.yml"
theme="hyde-wallbash"

[[ -f $theme_file ]] || exit 0

kitty_theme="${HYDE_THEME_DIR:-}/kitty.theme"
[[ -f $kitty_theme ]] || kitty_theme="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/theme.conf"

# LAGC Calm Dark kitty values as the last-resort palette; it is the closest
# neutral table when no HyDE kitty theme can be read.
declare -A ansi=(
    [0]=352E29 [1]=D67A6E [2]=A9C080 [3]=D4A55C [4]=8FA8A0 [5]=C98A6B
    [6]=9DB8A0 [7]=E9DFCE [8]=6B5F53 [9]=E0877B [10]=B9CC94 [11]=E0B876
    [12]=A8BDB0 [13]=D8A188 [14]=ADD0B8 [15]=F4EEE2
)
if [[ -f $kitty_theme ]]; then
    while read -r name value; do
        [[ $name =~ ^color([0-9]+)$ ]] || continue
        index=${BASH_REMATCH[1]}
        [[ $value =~ ^#[0-9A-Fa-f]{6}$ ]] || continue
        ansi[$index]=${value#\#}
    done < "$kitty_theme"
fi

mix() { # TINT BASE PCT(0-100) -> RRGGBB tint-over-base blend
    local t=$1 b=$2 p=$3
    printf '%02X%02X%02X' \
        $(( (16#${t:0:2} * p + 16#${b:0:2} * (100 - p) + 50) / 100 )) \
        $(( (16#${t:2:2} * p + 16#${b:2:2} * (100 - p) + 50) / 100 )) \
        $(( (16#${t:4:2} * p + 16#${b:4:2} * (100 - p) + 50) / 100 ))
}

base=${dcol_pry1:-}
base=${base#\#}
if [[ ! $base =~ ^[0-9A-Fa-f]{6}$ && -f $kitty_theme ]]; then
    base=$(awk '$1 == "background" && $2 ~ /^#[0-9A-Fa-f]{6}$/ { sub(/^#/, "", $2); print toupper($2); exit }' "$kitty_theme")
fi
[[ $base =~ ^[0-9A-Fa-f]{6}$ ]] || base=1D2021

tmp="$theme_file.tmp.$$"
if cp "$theme_file" "$tmp"; then
    for index in "${!ansi[@]}"; do
        sed -i \
            -e "s/@ANSI${index}@/${ansi[$index]}/g" \
            -e "s/@MIX_${index}@/$(mix "${ansi[$index]}" "$base" 18)/g" \
            "$tmp"
    done
    if grep -qE 'wallbash_|@ANSI[0-9]+@|@MIX_[0-9]+@' "$tmp"; then
        printf '[wallbash] warning: unresolved placeholders in %s\n' "$theme_file" >&2
    fi
    mv -f "$tmp" "$theme_file"
fi

# Select the theme in both auto slots. config.yml is OMP-owned YAML; only the
# scalar values inside the top-level "theme:" map are rewritten, every other
# key and section is preserved byte-for-byte.
if [[ -d $omp_dir ]]; then
    if [[ -f $config ]]; then
        if patched=$(awk -v theme="$theme" '
            /^theme[[:space:]]*:/ && !in_theme {
                in_theme = 1
                rest = $0
                sub(/^theme[[:space:]]*:[[:space:]]*/, "", rest)
                if (rest ~ /[^[:space:]#]/) {
                    # Legacy flat form "theme: name" becomes the nested map.
                    print "theme:"
                    print "  dark: " theme
                    print "  light: " theme
                    seen_dark = 1; seen_light = 1
                } else {
                    print
                }
                next
            }
            in_theme && /^[^[:space:]]/ {
                if (!seen_dark) print "  dark: " theme
                if (!seen_light) print "  light: " theme
                in_theme = 0
            }
            in_theme && /^[[:space:]]+dark[[:space:]]*:/ { print "  dark: " theme; seen_dark = 1; next }
            in_theme && /^[[:space:]]+light[[:space:]]*:/ { print "  light: " theme; seen_light = 1; next }
            { print }
            END {
                if (!in_theme && !seen_dark && !seen_light) {
                    print "theme:"
                    print "  dark: " theme
                    print "  light: " theme
                } else if (in_theme) {
                    if (!seen_dark) print "  dark: " theme
                    if (!seen_light) print "  light: " theme
                }
            }' "$config"); then
            printf '%s\n' "$patched" > "$config" || true
        fi
    else
        printf 'theme:\n  dark: %s\n  light: %s\n' "$theme" "$theme" > "$config" || true
    fi
fi

exit 0
