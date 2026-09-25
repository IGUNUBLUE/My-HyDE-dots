#!/usr/bin/env bash
# Splices the active HyDE kitty ANSI palette into the generated opencode theme
# and selects it. Semantic ANSI colors are not wallbash variables, so the .dcol
# carries @ANSIn@ markers resolved here; appended bytes (e.g. "@ANSI1@2E")
# become the alpha channel of the written hex color.
set -Eeuo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
theme_file="$config_dir/themes/hyde-wallbash.json"
theme="hyde-wallbash"

[[ -f "$theme_file" ]] || exit 0

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

tmp="$theme_file.tmp.$$"
if cp "$theme_file" "$tmp"; then
    for index in "${!ansi[@]}"; do
        sed -i "s/@ANSI${index}@/${ansi[$index]}/g" "$tmp"
    done
    if grep -qE 'wallbash_|@ANSI[0-9]+@' "$tmp"; then
        printf '[wallbash] warning: unresolved placeholders in %s\n' "$theme_file" >&2
    fi
    mv -f "$tmp" "$theme_file"
fi

# Select the theme. OpenCode v2 keeps the TUI theme in cli.json as a nested
# {"theme": {"name": ...}} object; v1 used a "theme" string in tui.json or
# opencode.json. Unknown keys in every file are preserved.
command -v python3 >/dev/null 2>&1 &&
python3 - "$config_dir" "$theme" <<'PY' || true
import json
import pathlib
import sys

config_dir = pathlib.Path(sys.argv[1])
theme = sys.argv[2]


def load(path):
    try:
        return json.loads(path.read_text())
    except Exception:
        return None


def save(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


cli = config_dir / "cli.json"
if cli.is_file():
    data = load(cli)
    if isinstance(data, dict):
        section = data.get("theme")
        if isinstance(section, dict):
            section["name"] = theme
        else:
            data["theme"] = {"name": theme}
        save(cli, data)
    sys.exit(0)

for name in ("tui.json", "opencode.json"):
    path = config_dir / name
    if not path.is_file():
        continue
    data = load(path)
    if isinstance(data, dict):
        data["theme"] = theme
        save(path, data)
        sys.exit(0)

if cli.parent.is_dir():
    save(cli, {"theme": {"name": theme}})
PY

# .jsonc variants keep their comments; only rewrite an existing "theme" value.
for jsonc in "$config_dir"/tui.jsonc "$config_dir"/opencode.jsonc; do
    [[ -f $jsonc ]] || continue
    sed -i -E 's|("theme"[[:space:]]*:[[:space:]]*)"[^"]*"|\1"'"$theme"'"|' "$jsonc" 2>/dev/null || true
done

# opencode TUIs refresh themes on SIGUSR2 (subscribeThemeSignal). Signal only
# processes that installed a handler — SigCgt bit for signal 12 — so daemons
# and one-shot commands (serve, run, acp) never get the default kill action.
if command -v pgrep >/dev/null 2>&1; then
    for pid in $(pgrep -x opencode 2>/dev/null); do
        mask=$(awk '/^SigCgt:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null) || continue
        if [[ -n $mask ]] && (( 16#$mask & (1 << 11) )); then
            kill -USR2 "$pid" 2>/dev/null || true
        fi
    done
fi

exit 0
