#!/usr/bin/env bash
# Follows the active HyDE theme in the Herdr desktop app (herdr-app).
#
# The app reads "theme" from ~/.config/herdr-app/settings.json and applies edits
# live, resolving a name against ~/.config/herdr-app/themes/<name>.json. The four
# LAGC themes map 1:1; any other HyDE theme falls back to the LAGC Calm pair by
# light/dark mode. Only the "theme" key is rewritten, atomically, and only when
# its value changes, so every other setting is preserved.
#
# A theme picked inside the app is stored in layouts/.state/<layout>.json and
# outranks settings.json. When such a pick exists and the app is running, the
# same family is pushed through `herdr-app do app.theme` (once per half of the
# light/dark pair) so the pick cannot freeze the app on an old theme. No pick is
# ever created by this hook.
set -Eeuo pipefail

conf_home="${XDG_CONFIG_HOME:-$HOME/.config}"
app_dir="$conf_home/herdr-app"
settings="$app_dir/settings.json"
marker="$app_dir/.wallbash-mode"

[[ -f $marker ]] || exit 0
mode=$(tr -d '[:space:]' < "$marker")
case "$mode" in
    dark|light) ;;
    *) exit 0 ;;
esac

# color.set.sh exports HYDE_THEME and HYDE_THEME_DIR to every template command;
# fall back to the state file when the script is run by hand.
active_theme=${HYDE_THEME:-}
if [[ -z $active_theme && -n ${HYDE_THEME_DIR:-} ]]; then
    active_theme=$(basename -- "$HYDE_THEME_DIR")
fi
if [[ -z $active_theme ]]; then
    staterc="${XDG_STATE_HOME:-$HOME/.local/state}/hyde/staterc"
    [[ -f $staterc ]] && active_theme=$(awk -F'"' '/^HYDE_THEME=/{print $2}' "$staterc")
fi

case "$active_theme" in
    "LAGC Calm Dark"|"LAGC Calm Light") family="lagc-calm" ;;
    "LAGC Tech Dark"|"LAGC Tech Light") family="lagc-tech" ;;
    *) family="lagc-calm" ;;
esac
want="$family-$mode"
# Never select a theme that is not installed.
[[ -f "$app_dir/themes/$want.json" ]] || exit 0

python3 - "$settings" "$want" <<'PY'
import json
import os
import sys

path, want = sys.argv[1], sys.argv[2]
try:
    with open(path) as handle:
        data = json.load(handle)
except FileNotFoundError:
    data = {}
except (OSError, ValueError):
    sys.exit(0)  # never overwrite a settings.json the app could not parse either
if not isinstance(data, dict):
    sys.exit(0)
if data.get("theme") == want:
    sys.exit(0)
data["theme"] = want
temporary = f"{path}.tmp.{os.getpid()}"
mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o644
with open(temporary, "w") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
os.chmod(temporary, mode)
os.replace(temporary, path)
PY

# Keep an in-app theme pick in step (see the header). Reading the click state is
# fine; it is never written here.
if command -v herdr-app >/dev/null && grep -qs '^  "theme"' "$app_dir"/layouts/.state/*.json 2>/dev/null; then
    for half in light dark; do
        [[ -f "$app_dir/themes/$family-$half.json" ]] || continue
        timeout 5 herdr-app do app.theme "{\"name\":\"$family-$half\"}" >/dev/null 2>&1 || true
    done
fi
exit 0
