#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pycache_dir=$(mktemp -d)
cursor_build_dir=$(mktemp -d)
trap 'rm -rf -- "$pycache_dir" "$cursor_build_dir"' EXIT
[[ -s "$repo_dir/AGENTS.md" ]] || { printf 'AGENTS.md is missing or empty.\n' >&2; exit 1; }
[[ -s "$repo_dir/memory/index.md" ]] || { printf 'Repository memory index is missing or empty.\n' >&2; exit 1; }
bash -n "$repo_dir/install.sh" "$repo_dir/restore.sh" "$repo_dir/update-snapshot.sh" "$repo_dir/check.sh"
grep -Fqx 'imagemagick' "$repo_dir/packages.arch"
command -v magick >/dev/null || {
    printf 'ImageMagick is required to generate distinct HyDE theme wallpapers.\n' >&2
    exit 1
}

for theme in "LAGC Tech Dark" "LAGC Tech Light" "LAGC Calm Dark" "LAGC Calm Light"; do
    theme_dir="$repo_dir/dotfiles/.config/hyde/themes/$theme"
    for theme_file in hypr.theme kitty.theme rofi.theme theme.dcol waybar.theme; do
        [[ -s "$theme_dir/$theme_file" ]] || {
            printf 'HyDE theme is missing %s: %s\n' "$theme_file" "$theme" >&2
            exit 1
        }
    done
    [[ $(<"$theme_dir/.sort") =~ ^[0-9]+$ ]] || {
        printf 'HyDE theme has an invalid or missing .sort value: %s\n' "$theme" >&2
        exit 1
    }
    bash -n "$theme_dir/theme.dcol"
    grep -Fqx '$HOME/.config/hypr/themes/theme.conf|> $HOME/.config/hypr/themes/colors.conf' "$theme_dir/hypr.theme"
    grep -Fqx '$HOME/.config/kitty/theme.conf|killall -SIGUSR1 kitty' "$theme_dir/kitty.theme"
    grep -Fqx '$HOME/.config/rofi/theme.rasi' "$theme_dir/rofi.theme"
    grep -Fqx '$HOME/.config/waybar/theme.css|${scrDir}/wbarconfgen.sh' "$theme_dir/waybar.theme"
    grep -Eq '^@define-color main-bg #[0-9A-F]{6};$' "$theme_dir/waybar.theme"
    grep -Eq '^    main-bg:[[:space:]]+#[0-9A-F]{8};$' "$theme_dir/rofi.theme"
    grep -Eq '^dcol_[1-4]xa[1-9]_rgba="rgba\([0-9]+,[0-9]+,[0-9]+,\\1\)"$' "$theme_dir/theme.dcol"
done

[[ $(<"$repo_dir/dotfiles/.config/hyde/themes/LAGC Tech Dark/.sort") -lt \
   $(<"$repo_dir/dotfiles/.config/hyde/themes/LAGC Tech Light/.sort") ]] || {
    printf 'LAGC Tech Dark must sort before LAGC Tech Light in the HyDE selector.\n' >&2
    exit 1
}
[[ $(<"$repo_dir/dotfiles/.config/hyde/themes/LAGC Calm Dark/.sort") -lt \
   $(<"$repo_dir/dotfiles/.config/hyde/themes/LAGC Calm Light/.sort") ]] || {
    printf 'LAGC Calm Dark must sort before LAGC Calm Light in the HyDE selector.\n' >&2
    exit 1
}
grep -Fq 'generate_theme_wallpaper "LAGC Tech Dark" "$theme_wallpaper" dark' "$repo_dir/install.sh"
grep -Fq 'generate_theme_wallpaper "LAGC Tech Light" "$theme_wallpaper" light' "$repo_dir/install.sh"
grep -Fq 'generate_calm_wallpaper "LAGC Calm Dark" dark' "$repo_dir/install.sh"
grep -Fq 'generate_calm_wallpaper "LAGC Calm Light" light' "$repo_dir/install.sh"
grep -Fq 'run hyde-shell wallpaper --cache wall "$target"' "$repo_dir/install.sh"

rofi_override="$repo_dir/dotfiles/.config/hyde/wallbash/always/rofi-frosted.dcol"
rofi_callback="$repo_dir/dotfiles/.local/bin/my-hyde-rofi-selection"
[[ -s "$rofi_override" && -s "$rofi_callback" ]] || {
    printf 'LAGC Rofi selection override is missing.\n' >&2
    exit 1
}
grep -Fqx '$HOME/.config/rofi/theme.rasi|"$HOME/.local/bin/my-hyde-rofi-selection"' "$rofi_override"
grep -Fqx '    main-bg:            #<wallbash_pry1>FF;' "$rofi_override"
grep -Fqx '    select-bg:          #<wallbash_4xa8>FF;' "$rofi_override"
grep -Fqx '    select-fg:          #<wallbash_4xa1>FF;' "$rofi_override"
if grep -Eq '^(#|//)' "$rofi_override"; then
    printf 'Rofi templates must not add standalone comments to generated Rasi.\n' >&2
    exit 1
fi
grep -Fq 'select-bg:          #17D7E8FF;' "$rofi_callback"
grep -Fq 'select-fg:          #061B2BFF;' "$rofi_callback"
bash -n "$rofi_callback"

if find "$repo_dir/dotfiles/.config/hyde/themes" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print -quit | grep -q .; then
    printf 'Theme wallpaper assets must not be tracked; install.sh links an existing user wallpaper instead.\n' >&2
    exit 1
fi

python "$repo_dir/tools/package-vscodium-theme.py" --check
if find "$repo_dir/dotfiles/.local/share/vscodium/themes" -type f -name '*.vsix' -print -quit | grep -q .; then
    printf 'Generated VSCodium VSIX packages must not be tracked; install.sh packages them temporarily.\n' >&2
    exit 1
fi

cursor_dir="$repo_dir/dotfiles/.local/share/icons/Future-cursors"
cursor_config="$repo_dir/dotfiles/.config/hyde/config.toml.in"
cursor_env="$repo_dir/dotfiles/.config/environment.d/90-cursor-theme.conf"
for cursor_file in index.theme LICENSE SOURCE.md cursors/default cursors/pointer; do
    [[ -e "$cursor_dir/$cursor_file" ]] || {
        printf 'Future Cursors payload is missing: %s\n' "$cursor_file" >&2
        exit 1
    }
done
grep -Fqx 'Name=Future Cursors' "$cursor_dir/index.theme"
grep -Fq '587c14d2f5bd2dc34095a4efbb1a729eb72a1d36' "$cursor_dir/SOURCE.md"
[[ $(find "$cursor_dir/cursors" -mindepth 1 -maxdepth 1 | wc -l) -eq 111 ]] || {
    printf 'Future Cursors payload must contain the complete 111-entry upstream cursor tree.\n' >&2
    exit 1
}
[[ $(find "$cursor_dir/cursors" -xtype l | wc -l) -eq 0 ]] || {
    printf 'Future Cursors contains broken alias symlinks.\n' >&2
    exit 1
}
[[ $(sha256sum "$cursor_dir/LICENSE" | cut -d' ' -f1) == 605e9047a563c5c8396ffb18232aa4304ec56586aee537c45064c6fb425e44ad ]] || {
    printf 'Future Cursors GPLv3 license differs from the pinned upstream copy.\n' >&2
    exit 1
}
[[ $(grep -Ec '^[[:space:]]*cursor_theme[[:space:]]*=[[:space:]]*"Future-cursors"[[:space:]]*$' "$cursor_config") -eq 1 ]] || {
    printf 'HyDE must select Future-cursors exactly once.\n' >&2
    exit 1
}
[[ $(grep -Ec '^[[:space:]]*cursor_size[[:space:]]*=[[:space:]]*46[[:space:]]*$' "$cursor_config") -eq 1 ]] || {
    printf 'HyDE must keep the accepted logical cursor size 46 for the mixed-scale displays.\n' >&2
    exit 1
}
[[ $(grep -Ec '^[[:space:]]*duration_scale[[:space:]]*=[[:space:]]*0[.]9[[:space:]]*$' "$cursor_config") -eq 1 ]] || {
    printf 'HyDE must keep the animation duration scale in config.toml, where the preset can read it.\n' >&2
    exit 1
}
grep -Fqx 'XCURSOR_THEME=Future-cursors' "$cursor_env"
# XCursor and Hyprcursor sizes are not 1:1: GTK/Qt/XWayland use 32 while the
# compositor keeps the visually equivalent 46.
grep -Fqx 'XCURSOR_SIZE=32' "$cursor_env"
grep -Fqx 'HYPRCURSOR_THEME=Future-cursors' "$cursor_env"
grep -Fqx 'HYPRCURSOR_SIZE=46' "$cursor_env"
# The gtk3-cursor-fix watcher restores the GTK3/XSETTINGS cursor size after
# each HyDE theme switch rewrites it with the compositor size.
cursor_fix="$repo_dir/dotfiles/.local/bin/gtk3-cursor-fix"
cursor_fix_path="$repo_dir/dotfiles/.config/systemd/user/gtk3-cursor-fix.path"
cursor_fix_service="$repo_dir/dotfiles/.config/systemd/user/gtk3-cursor-fix.service"
bash -n "$cursor_fix"
grep -Fq 'gtk-cursor-theme-size' "$cursor_fix"
grep -Fq 'Gtk/CursorThemeSize' "$cursor_fix"
grep -Fq 'PathModified=%h/.config/gtk-3.0/settings.ini' "$cursor_fix_path"
grep -Fq 'PathModified=%h/.config/xsettingsd/xsettingsd.conf' "$cursor_fix_path"
grep -Fq 'ExecStart=%h/.local/bin/gtk3-cursor-fix' "$cursor_fix_service"
hyprcursor_source="$repo_dir/cursor-sources/Future-cyan-hyprcursor"
grep -Fqx 'name = Future-cursors' "$hyprcursor_source/manifest.hl"
grep -Fqx 'hotspot_x = 0.16875' "$hyprcursor_source/hyprcursors/arrow/meta.hl"
grep -Fqx 'hotspot_y = 0.128125' "$hyprcursor_source/hyprcursors/arrow/meta.hl"
grep -Fqx 'hotspot_x = 0.425' "$hyprcursor_source/hyprcursors/pointer/meta.hl"
grep -Fqx 'hotspot_y = 0.190625' "$hyprcursor_source/hyprcursors/pointer/meta.hl"
grep -Fq 'cf4126d17f4520aceb688d8a60daca4a1f0b9e80' "$hyprcursor_source/SOURCE.md"
command -v hyprcursor-util >/dev/null || {
    printf 'hyprcursor-util is required to validate the native Future-cyan build.\n' >&2
    exit 1
}
hyprcursor-util --create "$hyprcursor_source" --output "$cursor_build_dir" >/dev/null
[[ -s "$cursor_build_dir/theme_Future-cursors/manifest.hl" ]] || {
    printf 'Native Future-cyan manifest was not generated.\n' >&2
    exit 1
}
[[ $(find "$cursor_build_dir/theme_Future-cursors/hyprcursors" -type f -name '*.hlc' | wc -l) -eq 45 ]] || {
    printf 'Native Future-cyan build must contain 45 Hyprcursor shapes.\n' >&2
    exit 1
}
for cursor_default in \
    "$repo_dir/dotfiles/.icons/default/index.theme" \
    "$repo_dir/dotfiles/.local/share/icons/default/index.theme"; do
    grep -Fqx 'Inherits=Future-cursors' "$cursor_default"
done

PYTHONPYCACHEPREFIX="$pycache_dir" python -m py_compile "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel"
python "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel" --status | python -m json.tool >/dev/null

waybar_layout="$repo_dir/dotfiles/.config/waybar/layouts/my-hyde.jsonc"
waybar_style="$repo_dir/dotfiles/.config/waybar/user-style.css"
[[ $(grep -Ec '^[[:space:]]*"height"[[:space:]]*:[[:space:]]*22,[[:space:]]*$' "$waybar_layout") -eq 1 ]] || {
    printf 'Waybar must keep the historical 22-pixel layout height.\n' >&2
    exit 1
}
grep -Fq $'window#waybar.top #pill * {\n    min-height: 0;\n}' "$waybar_style" || {
    printf 'Waybar must neutralize GTK minimum heights inside the user-owned pills.\n' >&2
    exit 1
}
for theme_name in "LAGC Tech Dark" "LAGC Tech Light"; do
    waybar_theme="$repo_dir/dotfiles/.config/hyde/themes/$theme_name/waybar.theme"
    for token in wb-ok-fg wb-info-fg wb-warn-fg wb-crit-fg; do
        grep -Eq "^@define-color $token #[0-9A-Fa-f]{6};$" "$waybar_theme" || {
            printf 'Waybar theme %s is missing the %s semantic state color.\n' "$theme_name" "$token" >&2
            exit 1
        }
    done
done
for token in wb-ok-fg wb-info-fg wb-warn-fg wb-crit-fg; do
    grep -Fq "@$token" "$waybar_style" || {
        printf 'Waybar user-style.css must consume the %s semantic state color.\n' "$token" >&2
        exit 1
    }
done

zsh_config="$repo_dir/dotfiles/.config/zsh/user.zsh"
if grep -Eq '^[[:space:]]*(pokego|pokemon-colorscripts|fastfetch)([[:space:]]|$)' "$zsh_config"; then
    printf 'Zsh must not run a system-information banner on every terminal startup.\n' >&2
    exit 1
fi
grep -Fqx '    "$PNPM_HOME/bin"' "$zsh_config" || {
    printf 'Zsh must expose PNPM global CLI binaries through $PNPM_HOME/bin.\n' >&2
    exit 1
}

hypridle_config="$repo_dir/dotfiles/.config/hypr/hypridle.conf"
[[ -s "$hypridle_config" ]] || { printf 'Hypridle override is missing or empty.\n' >&2; exit 1; }
if grep -Eq '^[[:space:]]*on-timeout[[:space:]]*=.*(loginctl lock-session|dispatch dpms off|systemctl suspend)' "$hypridle_config"; then
    printf 'Unsafe automatic lock, DPMS or suspend action found during hyprlock mitigation.\n' >&2
    exit 1
fi

kitty_config="$repo_dir/dotfiles/.config/kitty/kitty.conf"
[[ -s "$kitty_config" ]] || { printf 'Kitty user configuration is missing or empty.\n' >&2; exit 1; }
[[ $(grep -Ec '^[[:space:]]*font_size[[:space:]]+11([.]0)?[[:space:]]*$' "$kitty_config") -eq 1 ]] || {
    printf 'Kitty must define the portable 11 pt default exactly once.\n' >&2
    exit 1
}
[[ $(grep -Ec '^[[:space:]]*background_opacity[[:space:]]+0[.]97[[:space:]]*$' "$kitty_config") -eq 1 ]] || {
    printf 'Kitty must define the portable 0.97 background opacity exactly once.\n' >&2
    exit 1
}
if find "$repo_dir/dotfiles/.config/kitty" -maxdepth 1 -type f \( -name 'hyde.conf' -o -name 'theme.conf' \) -print -quit | grep -q .; then
    printf 'HyDE-managed Kitty files must not be tracked.\n' >&2
    exit 1
fi

hyprland_config="$repo_dir/dotfiles/.config/hypr/hyprland.lua"
[[ -s "$hyprland_config" ]] || { printf 'Hyprland override is missing or empty.\n' >&2; exit 1; }
grep -Pzq 'blur\s*=\s*\{\s*enabled\s*=\s*false,' "$hyprland_config" || {
    printf 'Hyprland must keep compositor blur disabled for the solid-first profile.\n' >&2
    exit 1
}
if grep -Eq '^[[:space:]]*opaque[[:space:]]*=[[:space:]]*true,$' "$hyprland_config"; then
    printf 'Hyprland must not force application windows opaque; it flattens blur, shadow and glow.\n' >&2
    exit 1
fi
for opacity_key in active_opacity inactive_opacity; do
    [[ $(grep -Ec "^[[:space:]]*$opacity_key[[:space:]]*=[[:space:]]*1,$" "$hyprland_config") -eq 1 ]] || {
        printf 'Application windows must stay fully opaque: %s = 1.\n' "$opacity_key" >&2
        exit 1
    }
done

btop_template="$repo_dir/dotfiles/.config/hyde/wallbash/always/btop.dcol"
btop_script="$repo_dir/dotfiles/.config/hyde/wallbash/scripts/my-hyde-btop.sh"
[[ -s "$btop_template" && -x "$btop_script" ]] || {
    printf 'Btop Wallbash template or theme selector is missing.\n' >&2
    exit 1
}
grep -Fqx '$HOME/.config/btop/themes/hyde-wallbash.theme|"$WALLBASH_SCRIPTS/my-hyde-btop.sh"' "$btop_template"
grep -Fqx 'theme[title]="#<wallbash_4xa8>"' "$btop_template"
bash -n "$btop_script"

# Agent CLI themes: the .dcol payloads are only valid JSON/XML once wallbash
# and the selector scripts replace every placeholder. Simulate that render
# (wallbash palette + kitty ANSI + blends) and parse the results for real.
python - "$repo_dir/dotfiles/.config/hyde/wallbash/always/opencode.dcol" \
         "$repo_dir/dotfiles/.config/hyde/wallbash/always/codex.dcol" <<'PY'
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

opencode_template = pathlib.Path(sys.argv[1])
codex_template = pathlib.Path(sys.argv[2])
PLACEHOLDER = re.compile(r"<wallbash_[0-9A-Za-z_]+>|@ANSI[0-9]+@|@MIX_[0-9]+@")


def render(path):
    lines = path.read_text().splitlines()
    return PLACEHOLDER.sub("A9C080", "\n".join(lines[1:])).replace("\\$", "$")


def fail(message):
    print(f"Wallbash agent template invalid: {message}", file=sys.stderr)
    sys.exit(1)


expected_headers = {
    opencode_template: '${XDG_CONFIG_HOME:-$HOME/.config}/opencode/themes/hyde-wallbash.json|"$WALLBASH_SCRIPTS/my-hyde-opencode-theme.sh"',
    codex_template: '${CODEX_HOME:-$HOME/.codex}/themes/hyde-wallbash.tmTheme|"$WALLBASH_SCRIPTS/my-hyde-codex-theme.sh"',
}
for path, header in expected_headers.items():
    first = path.read_text().splitlines()[0]
    if first != header:
        fail(f"unexpected .dcol header in {path.name}: {first}")

try:
    theme = json.loads(render(opencode_template))["theme"]
except Exception as exc:
    fail(f"opencode theme JSON does not parse after render: {exc}")

required = {
    "primary", "secondary", "accent", "error", "warning", "success", "info",
    "text", "textMuted", "background", "backgroundPanel", "backgroundElement",
    "border", "borderActive", "borderSubtle", "diffAdded", "diffRemoved",
    "diffContext", "diffHunkHeader", "diffHighlightAdded", "diffHighlightRemoved",
    "diffAddedBg", "diffRemovedBg", "diffContextBg", "diffLineNumber",
    "diffAddedLineNumberBg", "diffRemovedLineNumberBg", "markdownText",
    "markdownHeading", "markdownLink", "markdownLinkText", "markdownCode",
    "markdownBlockQuote", "markdownEmph", "markdownStrong",
    "markdownHorizontalRule", "markdownListItem", "markdownListEnumeration",
    "markdownImage", "markdownImageText", "markdownCodeBlock", "syntaxComment",
    "syntaxKeyword", "syntaxFunction", "syntaxVariable", "syntaxString",
    "syntaxNumber", "syntaxType", "syntaxOperator", "syntaxPunctuation",
}
missing = sorted(required - set(theme))
if missing:
    fail(f"opencode theme is missing semantic keys: {missing}")

try:
    ET.fromstring(render(codex_template))
except Exception as exc:
    fail(f"codex tmTheme XML does not parse after render: {exc}")

codex_body = codex_template.read_text()
for scope in ("markup.inserted", "markup.deleted", "comment", "keyword",
              "string", "entity.name.function", "variable", "markup.heading",
              "invalid"):
    if scope not in codex_body:
        fail(f"codex tmTheme is missing scope coverage: {scope}")
for marker in ("@MIX_1@", "@MIX_2@"):
    if marker not in codex_body:
        fail(f"codex tmTheme is missing diff background marker: {marker}")
PY

opencode_selector="$repo_dir/dotfiles/.config/hyde/wallbash/scripts/my-hyde-opencode-theme.sh"
codex_selector="$repo_dir/dotfiles/.config/hyde/wallbash/scripts/my-hyde-codex-theme.sh"
for selector in "$opencode_selector" "$codex_selector"; do
    [[ -x $selector ]] || {
        printf 'Agent theme selector is missing or not executable: %s\n' "$selector" >&2
        exit 1
    }
    bash -n "$selector"
done
grep -Fq 'section["name"] = theme' "$opencode_selector"
grep -Fq 'kill -USR2' "$opencode_selector"
grep -Fq 'SigCgt' "$opencode_selector"
grep -Fq 'theme = "' "$codex_selector"
grep -Fq 'ansi_color' "$codex_selector"

gtk_mode_template="$repo_dir/dotfiles/.config/hyde/wallbash/always/gtk-dark-mode.dcol"
gtk_mode_script="$repo_dir/dotfiles/.config/hyde/wallbash/scripts/my-hyde-gtk-dark-mode.sh"
[[ -s "$gtk_mode_template" && -x "$gtk_mode_script" ]] || {
    printf 'GTK dark-mode hook is missing or not executable.\n' >&2
    exit 1
}
grep -Fqx '$HOME/.config/gtk-3.0/.wallbash-dark-mode|"$WALLBASH_SCRIPTS/my-hyde-gtk-dark-mode.sh"' "$gtk_mode_template"
bash -n "$gtk_mode_script"
grep -Fq 'gtk-application-prefer-dark-theme' "$gtk_mode_script"

python "$repo_dir/tests/qt-menu.py"

while IFS= read -r memory_link; do
    [[ -f "$repo_dir/memory/$memory_link" ]] || {
        printf 'Memory index points to a missing file: %s\n' "$memory_link" >&2
        exit 1
    }
done < <(grep -oE '\]\([^)]*[.]md\)' "$repo_dir/memory/index.md" | sed -E 's/^\]\((.*)\)$/\1/')

while IFS= read -r memory_file; do
    for heading in '## Context' '## Evidence' '## Decision' '## Validation' '## Exit criteria'; do
        grep -Fqx "$heading" "$memory_file" || {
            printf 'Memory %s is missing required section: %s\n' "${memory_file#"$repo_dir/"}" "$heading" >&2
            exit 1
        }
    done
    grep -Eq '^- Status: (active|monitoring|resolved|superseded)$' "$memory_file" || {
        printf 'Memory %s has an invalid or missing status.\n' "${memory_file#"$repo_dir/"}" >&2
        exit 1
    }
done < <(find "$repo_dir/memory" -mindepth 2 -type f -name '*.md' -print)

if rg -n -i '(BEGIN [A-Z ]*PRIVATE KEY|github_pat_|ghp_|api[_-]?key[[:space:]]*=|password[[:space:]]*=|token[[:space:]]*=)' "$repo_dir" --glob '!check.sh'; then
    printf 'Potential secret found. Refusing validation.\n' >&2
    exit 1
fi

printf 'All checks passed.\n'
