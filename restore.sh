#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${1:-} == "--vscodium-theme-only" ]]; then
    command -v codium >/dev/null || {
        printf 'VSCodium CLI not found; cannot remove the LAGC Calm VSCodium themes.\n' >&2
        exit 1
    }
    codium --uninstall-extension igunublue.lagc-themes
    codium --uninstall-extension igunublue.lagc-calm-themes
    printf 'LAGC Calm VSCodium themes removed.\n'
    exit 0
fi

if [[ ${1:-} == "--rhun-theme-only" ]]; then
    # Removes only overlay-owned files. ~/.config/rhun/config is rhun's own file
    # and stays; a [ui] theme naming a removed LAGC theme falls back to rhun's
    # default theme, and a font path that no longer exists to the built-in font.
    rhun_dir="${XDG_CONFIG_HOME:-$HOME/.config}/rhun"
    for rhun_theme in lagc-calm-dark lagc-calm-light lagc-tech-dark lagc-tech-light; do
        rm -f -- "$HOME/.config/rhun/themes/$rhun_theme.theme"
    done
    rm -f -- "$HOME/.config/hyde/wallbash/always/rhun-theme.dcol" \
        "$HOME/.config/hyde/wallbash/scripts/my-hyde-rhun-theme.sh" \
        "$rhun_dir/.wallbash-mode" "$rhun_dir/fonts/ui.ttf" "$rhun_dir/fonts/editor.ttf"
    rmdir -- "$rhun_dir/fonts" 2>/dev/null || true
    printf 'LAGC rhun themes, extracted fonts and the theme-follow hook removed.\n'
    exit 0
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/my-hyde-dots/backups"
backup=${1:-}

if [[ -z "$backup" ]]; then
    backup=$(find "$state_dir" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null | sort | tail -n 1)
fi

if [[ -z "$backup" || ! -d "$backup" ]]; then
    printf 'No backup found. Pass a backup directory explicitly.\n' >&2
    exit 1
fi

backup=$(realpath -- "$backup")
state_dir=$(realpath -- "$state_dir")
case "$backup" in
    "$state_dir"/*) ;;
    *) printf 'Refusing backup outside %s\n' "$state_dir" >&2; exit 1 ;;
esac

validate_relative() {
    local relative=$1
    [[ -n "$relative" && "$relative" != /* && "$relative" != *'..'* ]] || {
        printf 'Unsafe backup entry: %s\n' "$relative" >&2
        exit 1
    }
}

read_setting() {
    local wanted=$1 source=$2 key value
    while IFS='=' read -r key value; do
        if [[ $key == "$wanted" ]]; then
            printf '%s' "$value"
            return 0
        fi
    done < "$source"
    return 0
}

remove_path() {
    local target=$1
    if [[ -d "$target" && ! -L "$target" ]]; then
        rm -rf -- "$target"
    else
        rm -f -- "$target"
    fi
}

systemctl --user disable --now gtk3-cursor-fix.path 2>/dev/null || true

printf 'Restoring files from %s\n' "$backup"
if [[ -f "$backup/.created" ]]; then
    while IFS= read -r relative; do
        validate_relative "$relative"
        remove_path "$HOME/$relative"
    done < "$backup/.created"
fi

if [[ -f "$backup/.trees" ]]; then
    while IFS= read -r relative; do
        validate_relative "$relative"
        source="$backup/$relative"
        [[ -d "$source" && ! -L "$source" ]] || {
            printf 'Backed-up tree is missing: %s\n' "$relative" >&2
            exit 1
        }
        target="$HOME/$relative"
        remove_path "$target"
        mkdir -p -- "$(dirname -- "$target")"
        cp -a -- "$source" "$target"
    done < "$backup/.trees"
fi

while IFS= read -r -d '' source; do
    relative=${source#"$backup"/}
    target="$HOME/$relative"
    mkdir -p -- "$(dirname -- "$target")"
    cp -a -- "$source" "$target"
done < <(find "$backup" -path "$backup/.system" -prune -o -type f ! -name .created ! -name .trees \
    ! -name .cursor-state ! -name .system-created -print0)

# System files outside $HOME (install.sh `system` module). Only the same
# allowlist install.sh writes may be touched; anything else is refused.
system_files=(etc/systemd/logind.conf.d/10-my-hyde-lid.conf)
system_allowed() {
    local wanted=$1 entry
    for entry in "${system_files[@]}"; do
        [[ $entry == "$wanted" ]] && return 0
    done
    printf 'Refusing system path outside the overlay allowlist: /%s\n' "$wanted" >&2
    exit 1
}
system_changed=false
if [[ -f "$backup/.system-created" ]]; then
    while IFS= read -r relative; do
        validate_relative "$relative"
        system_allowed "$relative"
        sudo rm -f -- "/$relative"
        system_changed=true
    done < "$backup/.system-created"
fi
if [[ -d "$backup/.system" ]]; then
    while IFS= read -r -d '' source; do
        relative=${source#"$backup/.system"/}
        validate_relative "$relative"
        system_allowed "$relative"
        sudo install -Dm0644 -- "$source" "/$relative"
        system_changed=true
    done < <(find "$backup/.system" -type f -print0)
fi
if $system_changed; then
    sudo systemctl reload systemd-logind || true
fi

[[ -f "$HOME/.local/bin/hyde-brightness-panel" ]] && chmod 0755 "$HOME/.local/bin/hyde-brightness-panel"
hyde-shell waybar --update 2>/dev/null || true
hyprctl reload >/dev/null 2>&1 || true

if [[ -f "$backup/.cursor-state" ]] && command -v gsettings >/dev/null; then
    cursor_theme=$(read_setting theme "$backup/.cursor-state")
    cursor_size=$(read_setting size "$backup/.cursor-state")
    if [[ -n "$cursor_theme" && "$cursor_size" =~ ^[0-9]+$ ]]; then
        gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"
        gsettings set org.gnome.desktop.interface cursor-size "$cursor_size"
    fi
fi

cursor_env="$HOME/.config/environment.d/90-cursor-theme.conf"
if [[ -f "$cursor_env" ]]; then
    cursor_theme=$(read_setting XCURSOR_THEME "$cursor_env")
    cursor_size=$(read_setting XCURSOR_SIZE "$cursor_env")
    hyprcursor_theme=$(read_setting HYPRCURSOR_THEME "$cursor_env")
    hyprcursor_size=$(read_setting HYPRCURSOR_SIZE "$cursor_env")
    if [[ -n "$cursor_theme" && "$cursor_size" =~ ^[0-9]+$ ]]; then
        systemctl --user set-environment "XCURSOR_THEME=$cursor_theme" "XCURSOR_SIZE=$cursor_size" || true
        dbus-update-activation-environment --systemd "XCURSOR_THEME=$cursor_theme" "XCURSOR_SIZE=$cursor_size" || true
    fi
    if [[ -n "$hyprcursor_theme" && "$hyprcursor_size" =~ ^[0-9]+$ ]]; then
        systemctl --user set-environment "HYPRCURSOR_THEME=$hyprcursor_theme" "HYPRCURSOR_SIZE=$hyprcursor_size" || true
        dbus-update-activation-environment --systemd "HYPRCURSOR_THEME=$hyprcursor_theme" "HYPRCURSOR_SIZE=$hyprcursor_size" || true
    else
        systemctl --user unset-environment HYPRCURSOR_THEME HYPRCURSOR_SIZE || true
    fi
else
    systemctl --user unset-environment XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE || true
fi
printf 'Restore completed.\n'
