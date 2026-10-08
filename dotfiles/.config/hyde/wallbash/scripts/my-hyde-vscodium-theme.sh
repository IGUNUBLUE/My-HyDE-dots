#!/usr/bin/env bash
# Follows the active HyDE theme in VSCodium.
#
# The lagc-themes extension only contributes the four LAGC themes; nothing
# selected one on a theme switch. With "window.autoDetectColorScheme": true,
# VSCodium ignores workbench.colorTheme and picks preferredDarkColorTheme or
# preferredLightColorTheme from the system colour scheme, so all three keys are
# set: the LAGC theme of the active HyDE theme, its family for both preferred
# slots, and the Calm family for any non-LAGC HyDE theme. VSCodium watches
# settings.json and applies the change live. Only those keys are rewritten;
# comments and every other setting are kept, an unparseable file is left alone,
# and an unchanged file is not rewritten.
set -Eeuo pipefail

user_dir="${XDG_CONFIG_HOME:-$HOME/.config}/VSCodium/User"
settings="$user_dir/settings.json"
marker="$user_dir/.wallbash-mode"

[[ -f $marker ]] || exit 0
mode=$(tr -d '[:space:]' < "$marker")
case "$mode" in
    dark|light) ;;
    *) exit 0 ;;
esac

active_theme=${HYDE_THEME:-}
if [[ -z $active_theme && -n ${HYDE_THEME_DIR:-} ]]; then
    active_theme=$(basename -- "$HYDE_THEME_DIR")
fi
if [[ -z $active_theme ]]; then
    staterc="${XDG_STATE_HOME:-$HOME/.local/state}/hyde/staterc"
    [[ -f $staterc ]] && active_theme=$(awk -F'"' '/^HYDE_THEME=/{print $2}' "$staterc")
fi

case "$active_theme" in
    "LAGC Calm Dark"|"LAGC Calm Light"|"LAGC Tech Dark"|"LAGC Tech Light") theme=$active_theme ;;
    *) theme="LAGC Calm ${mode^}" ;;
esac
family=${theme% *}   # "LAGC Calm" / "LAGC Tech"

python3 - "$settings" "$theme" "$family Dark" "$family Light" <<'PY'
import json
import os
import re
import sys

path, theme, dark, light = sys.argv[1:5]
wanted = {
    "workbench.colorTheme": theme,
    "workbench.preferredDarkColorTheme": dark,
    "workbench.preferredLightColorTheme": light,
}


def strip_jsonc(text: str) -> str:
    # Drop // and /* */ comments outside strings, then trailing commas.
    out, i, in_str = [], 0, False
    while i < len(text):
        ch = text[i]
        if in_str:
            out.append(ch)
            if ch == "\\":
                out.append(text[i + 1:i + 2]); i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True; out.append(ch)
        elif text.startswith("//", i):
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = len(text) if end < 0 else end + 2
            continue
        else:
            out.append(ch)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


original = open(path, encoding="utf-8").read() if os.path.exists(path) else "{\n}\n"
try:
    current = json.loads(strip_jsonc(original) or "{}")
except ValueError:
    sys.exit(0)  # never rewrite a file VSCodium itself could not read
if not isinstance(current, dict):
    sys.exit(0)
if all(current.get(k) == v for k, v in wanted.items()):
    sys.exit(0)

text = original
for key, value in wanted.items():
    encoded = json.dumps(value)
    pattern = re.compile(r'^(\s*)"' + re.escape(key) + r'"\s*:\s*"(?:[^"\\]|\\.)*"', re.M)
    if pattern.search(text):
        text = pattern.sub(lambda m: f'{m.group(1)}"{key}": {encoded}', text, count=1)
    else:
        brace = text.index("{")
        body = text[brace + 1:].strip()
        sep = "," if body and not body.startswith("}") else ""
        text = f'{text[:brace + 1]}\n    "{key}": {encoded}{sep}{text[brace + 1:]}'

try:
    json.loads(strip_jsonc(text))
except ValueError:
    sys.exit(0)
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    handle.write(text)
os.replace(tmp, path)
PY
