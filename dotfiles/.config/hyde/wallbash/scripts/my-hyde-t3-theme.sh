#!/usr/bin/env bash
# Apply the matching published theme to the local T3 Code environment.
set -Eeuo pipefail
marker="$HOME/.t3/userdata/.wallbash-mode"
[[ -f $marker ]] || exit 0
mode=$(tr -d '[:space:]' < "$marker")
case "$mode" in dark|light) ;; *) exit 0 ;; esac
active_theme=${HYDE_THEME:-}
if [[ -z $active_theme && -n ${HYDE_THEME_DIR:-} ]]; then
    active_theme=$(basename -- "$HYDE_THEME_DIR")
fi
if [[ -z $active_theme ]]; then
    staterc="${XDG_STATE_HOME:-$HOME/.local/state}/hyde/staterc"
    [[ -f $staterc ]] && active_theme=$(awk -F'"' '/^HYDE_THEME=/{print $2}' "$staterc")
fi
case "$active_theme" in
    'LAGC Calm Dark')  want=lagc-calm-dark ;;
    'LAGC Calm Light') want=lagc-calm-light ;;
    'LAGC Tech Dark')  want=lagc-tech-dark ;;
    'LAGC Tech Light') want=lagc-tech-light ;;
    *) want="lagc-calm-$mode" ;;
esac
[[ -f "$HOME/.t3/userdata/themes/$want.json" ]] || exit 0
# Desktop installs this launcher independently of the user's PATH. Use an
# explicit base directory so an inherited T3CODE_HOME cannot redirect changes.
if [[ -x "$HOME/.t3/bin/t3" ]]; then
    cli="$HOME/.t3/bin/t3"
elif command -v t3 >/dev/null 2>&1; then
    cli=$(command -v t3)
else
    exit 0
fi
"$cli" theme set --base-dir "$HOME/.t3" "$want" >/dev/null
