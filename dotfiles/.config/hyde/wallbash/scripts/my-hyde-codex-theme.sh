#!/usr/bin/env bash
# Blends kitty ANSI diff backgrounds into the generated .tmTheme and selects it
# in config.toml. Syntect backgrounds cannot encode ANSI indices (only
# foregrounds can, via #NN000000), so the .dcol carries @MIX_1@/@MIX_2@ markers
# resolved here to 18% tints over the theme background.
set -Eeuo pipefail

codex_home="${CODEX_HOME:-$HOME/.codex}"
theme_file="$codex_home/themes/hyde-wallbash.tmTheme"
config="$codex_home/config.toml"
theme="hyde-wallbash"

[[ -f $theme_file ]] || exit 0

kitty_theme="${HYDE_THEME_DIR:-}/kitty.theme"
[[ -f $kitty_theme ]] || kitty_theme="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/theme.conf"

ansi_color() {
    [[ -f $kitty_theme ]] || return 0
    awk -v n="color$1" '$1 == n && $2 ~ /^#[0-9A-Fa-f]{6}$/ { sub(/^#/, "", $2); print toupper($2); exit }' "$kitty_theme"
}

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
added=$(ansi_color 2)
removed=$(ansi_color 1)

if [[ $base =~ ^[0-9A-Fa-f]{6}$ && -n $added && -n $removed ]]; then
    sed -i \
        -e "s/@MIX_2@/$(mix "$added" "$base" 18)/g" \
        -e "s/@MIX_1@/$(mix "$removed" "$base" 18)/g" \
        "$theme_file"
else
    # Without a palette, drop the tinted backgrounds; codex falls back to its
    # built-in diff colors instead of reading unresolved markers.
    sed -i '/<key>background<\/key>/{N;/@MIX_[12]@/d}' "$theme_file"
fi

# Select the theme under [tui] only; every other key and section is preserved.
if [[ -f $config ]]; then
    if patched=$(awk -v theme="$theme" '
        /^\[[[:space:]]*tui[[:space:]]*\][[:space:]]*$/ && !in_tui { in_tui = 1; print; next }
        /^\[/ && in_tui { if (!done) { print "theme = \"" theme "\""; done = 1 }; in_tui = 0; print; next }
        in_tui && /^[[:space:]]*theme[[:space:]]*=/ { print "theme = \"" theme "\""; done = 1; next }
        { print }
        END {
            if (!in_tui && !done) print "\n[tui]\ntheme = \"" theme "\""
            else if (in_tui && !done) print "theme = \"" theme "\""
        }' "$config"); then
        printf '%s\n' "$patched" > "$config" || true
    fi
else
    printf '[tui]\ntheme = "%s"\n' "$theme" > "$config" || true
fi

exit 0
