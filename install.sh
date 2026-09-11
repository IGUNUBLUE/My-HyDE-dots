#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/my-hyde-dots"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$state_dir/backups/$timestamp"
dry_run=false
skip_packages=false
qt_menu_only=false
kiro_theme_only=false
zed_theme_only=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--skip-packages] [--qt-menu-only] [--kiro-theme-only] [--zed-theme-only]

Applies this personal overlay after an official HyDE installation.
Existing target files are backed up under ~/.local/state/my-hyde-dots/backups/.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=true ;;
        --qt-menu-only) qt_menu_only=true; skip_packages=true ;;
        --kiro-theme-only) kiro_theme_only=true; skip_packages=true ;;
        --zed-theme-only) zed_theme_only=true; skip_packages=true ;;
        --skip-packages) skip_packages=true ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

run() {
    if $dry_run; then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

install_kiro_theme() {
    local required=${1:-false} temporary_dir package

    if ! command -v kiro >/dev/null; then
        printf 'Kiro CLI not found; LAGC Tech Kiro IDE themes were not installed.\n' >&2
        $required && return 1
        return 0
    fi

    if $dry_run; then
        run python "$repo_dir/tools/package-kiro-theme.py" --output "/tmp/igunublue.lagc-tech-themes-0.1.1.vsix"
        run kiro --install-extension "/tmp/igunublue.lagc-tech-themes-0.1.1.vsix" --force
        return 0
    fi

    temporary_dir=$(mktemp -d)
    package="$temporary_dir/igunublue.lagc-tech-themes-0.1.1.vsix"
    if ! python "$repo_dir/tools/package-kiro-theme.py" --output "$package"; then
        rm -rf -- "$temporary_dir"
        return 1
    fi
    if ! kiro --install-extension "$package" --force; then
        rm -rf -- "$temporary_dir"
        return 1
    fi
    rm -rf -- "$temporary_dir"
}

install_zed_theme() {
    local theme_source="$repo_dir/dotfiles/.config/zed/themes/lagc-tech.json"
    local settings_source="$repo_dir/dotfiles/.config/zed/lagc-tech-settings.json"
    local settings_target="$HOME/.config/zed/settings.json"

    install_dot "$theme_source" "$HOME/.config/zed/themes/lagc-tech.json"
    backup_target "$settings_target"
    run python "$repo_dir/tools/merge-zed-settings.py" \
        --settings "$settings_source" \
        --theme "$theme_source" \
        --target "$settings_target"
}

only_install_count=0
$qt_menu_only && ((only_install_count += 1))
$kiro_theme_only && ((only_install_count += 1))
$zed_theme_only && ((only_install_count += 1))
if ((only_install_count > 1)); then
    printf 'Use only one of --qt-menu-only, --kiro-theme-only or --zed-theme-only.\n' >&2
    exit 2
fi

if $kiro_theme_only; then
    install_kiro_theme true
    printf 'LAGC Tech Kiro IDE themes installed. Select one with Preferences: Color Theme.\n'
    exit 0
fi

if ! $zed_theme_only && { [[ ! -f "$HOME/.local/share/hypr/hyde.lua" ]] || ! command -v hyde-shell >/dev/null; }; then
    printf 'HyDE is not installed. Install/update official HyDE first, then rerun this overlay.\n' >&2
    exit 1
fi

backup_target() {
    local target=$1 relative
    relative=${target#"$HOME"/}
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        if $dry_run; then
            printf '[dry-run] mark-created %q\n' "$relative"
        else
            mkdir -p "$backup_dir"
            printf '%s\n' "$relative" >> "$backup_dir/.created"
        fi
        return 0
    fi
    if [[ -d "$target" && ! -L "$target" ]]; then
        if $dry_run; then
            printf '[dry-run] mark-tree %q\n' "$relative"
        else
            mkdir -p "$backup_dir"
            printf '%s\n' "$relative" >> "$backup_dir/.trees"
        fi
    fi
    run mkdir -p "$backup_dir/$(dirname -- "$relative")"
    run cp -a -- "$target" "$backup_dir/$relative"
}

install_dot() {
    local source=$1 target=$2 mode=${3:-0644}
    backup_target "$target"
    run install -Dm"$mode" -- "$source" "$target"
}

install_tree() {
    local source=$1 target=$2

    [[ -d "$source" ]] || {
        printf 'Install tree is missing: %s\n' "$source" >&2
        return 1
    }
    backup_target "$target"
    if [[ -d "$target" && ! -L "$target" ]]; then
        run rm -rf -- "$target"
    else
        run rm -f -- "$target"
    fi
    run mkdir -p -- "$(dirname -- "$target")"
    run cp -a -- "$source" "$target"
}

backup_cursor_state() {
    if $dry_run; then
        printf '[dry-run] record GTK cursor state\n'
        return 0
    fi
    command -v gsettings >/dev/null || return 0
    local cursor_theme cursor_size
    cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme)
    cursor_theme=${cursor_theme#\'}
    cursor_theme=${cursor_theme%\'}
    cursor_size=$(gsettings get org.gnome.desktop.interface cursor-size)
    mkdir -p "$backup_dir"
    printf 'theme=%s\nsize=%s\n' "$cursor_theme" "$cursor_size" > "$backup_dir/.cursor-state"
}

if $zed_theme_only; then
    install_zed_theme
    printf 'LAGC Tech Zed themes installed and selected in ~/.config/zed/settings.json.\n'
    exit 0
fi

install_zed_theme

install_theme_files() {
    local theme_name=$1 source_dir
    source_dir="$repo_dir/dotfiles/.config/hyde/themes/$theme_name"
    local source relative

    while IFS= read -r -d '' source; do
        relative=${source#"$source_dir"/}
        install_dot "$source" "$HOME/.config/hyde/themes/$theme_name/$relative"
    done < <(find "$source_dir" -type f -print0)
}

link_theme_wallpaper() {
    local theme_name=$1 wallpaper=$2 theme_dir wallpaper_dir target
    theme_dir="$HOME/.config/hyde/themes/$theme_name"
    wallpaper_dir="$theme_dir/wallpapers"
    target="$theme_dir/wall.set"

    [[ -f "$wallpaper" ]] || return 0
    if [[ ! -d "$wallpaper_dir" ]]; then
        backup_target "$wallpaper_dir"
        run mkdir -p -- "$wallpaper_dir"
    fi

    backup_target "$target"
    run rm -f -- "$target"
    run ln -s -- "$wallpaper" "$target"

    target="$wallpaper_dir/lagc-tech-wallpaper.${wallpaper##*.}"
    backup_target "$target"
    run rm -f -- "$target"
    run ln -s -- "$wallpaper" "$target"
}

remove_target() {
    local target=$1

    [[ -e "$target" || -L "$target" ]] || return 0
    backup_target "$target"
    run rm -f -- "$target"
}

install_qt_menu() {
    local source="" candidate
    for candidate in "${XDG_DATA_HOME:-$HOME/.local/share}/wallbash/theme/kvantum/kvconfig.dcol" \
        /usr/local/share/hyde/wallbash/theme/kvantum/kvconfig.dcol \
        /usr/share/hyde/wallbash/theme/kvantum/kvconfig.dcol; do
        [[ -f "$candidate" ]] && { source="$candidate"; break; }
    done
    [[ -n "$source" ]] || { printf 'Upstream Kvantum template missing.\n' >&2; return 1; }
    install_dot "$repo_dir/dotfiles/.config/hyde/qt-menu.ini" "$HOME/.config/hyde/qt-menu.ini"
    install_dot "$repo_dir/dotfiles/.local/bin/my-hyde-qt-menu" "$HOME/.local/bin/my-hyde-qt-menu" 0755
    local target="$HOME/.config/wallbash/theme/kvantum/kvconfig.dcol"
    backup_target "$target"
    run python "$repo_dir/dotfiles/.local/bin/my-hyde-qt-menu" --prepare "$source" "$target"
}

install_qt_menu
if $qt_menu_only; then
    if ! $dry_run; then
        "$HOME/.local/bin/my-hyde-qt-menu"
        printf 'Qt menu preferences installed. Backup: %s\n' "$backup_dir"
    fi
    exit 0
fi

if ! $skip_packages; then
    missing=()
    while IFS= read -r package; do
        [[ -n "$package" && "$package" != \#* ]] || continue
        pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
    done < "$repo_dir/packages.arch"
    if ((${#missing[@]})); then
        run sudo pacman -S --needed "${missing[@]}"
    fi
fi

backup_cursor_state
command -v hyprcursor-util >/dev/null || {
    printf 'hyprcursor-util is required to build the native Future-cyan cursor.\n' >&2
    exit 1
}
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
config_source="$repo_dir/dotfiles/.config/hyde/config.toml.in"
config_tmp="$work_dir/config.toml"
cursor_stage="$work_dir/Future-cursors"
cursor_build="$work_dir/hyprcursor-build"
sed "s|@HOME@|$HOME|g" "$config_source" > "$config_tmp"
cp -a -- "$repo_dir/dotfiles/.local/share/icons/Future-cursors" "$cursor_stage"
mkdir -p -- "$cursor_build"
hyprcursor-util --create "$repo_dir/cursor-sources/Future-cyan-hyprcursor" --output "$cursor_build" >/dev/null
cp -a -- "$cursor_build/theme_Future-cursors/manifest.hl" "$cursor_stage/manifest.hl"
cp -a -- "$cursor_build/theme_Future-cursors/hyprcursors" "$cursor_stage/hyprcursors"
cp -a -- "$repo_dir/cursor-sources/Future-cyan-hyprcursor/SOURCE.md" "$cursor_stage/HYPRCURSOR_SOURCE.md"

install_dot "$config_tmp" "$HOME/.config/hyde/config.toml"
install_dot "$repo_dir/dotfiles/.config/environment.d/90-cursor-theme.conf" "$HOME/.config/environment.d/90-cursor-theme.conf"
install_tree "$cursor_stage" "$HOME/.local/share/icons/Future-cursors"
install_dot "$repo_dir/dotfiles/.icons/default/index.theme" "$HOME/.icons/default/index.theme"
install_dot "$repo_dir/dotfiles/.local/share/icons/default/index.theme" "$HOME/.local/share/icons/default/index.theme"
install_dot "$repo_dir/dotfiles/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
install_dot "$repo_dir/dotfiles/.config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
install_dot "$repo_dir/dotfiles/.config/waybar/layouts/my-hyde.jsonc" "$HOME/.config/waybar/layouts/my-hyde.jsonc"
install_dot "$repo_dir/dotfiles/.config/waybar/modules/brightness-panel.jsonc" "$HOME/.config/waybar/modules/brightness-panel.jsonc"
install_dot "$repo_dir/dotfiles/.config/waybar/user-style.css" "$HOME/.config/waybar/user-style.css"
install_dot "$repo_dir/dotfiles/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
install_dot "$repo_dir/dotfiles/.config/zsh/user.zsh" "$HOME/.config/zsh/user.zsh"
install_dot "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel" "$HOME/.local/bin/hyde-brightness-panel" 0755
install_dot "$repo_dir/dotfiles/.config/hyde/wallbash/always/rofi-frosted.dcol" "$HOME/.config/hyde/wallbash/always/rofi-frosted.dcol"
install_dot "$repo_dir/dotfiles/.config/hyde/wallbash/always/btop.dcol" "$HOME/.config/hyde/wallbash/always/btop.dcol"
install_dot "$repo_dir/dotfiles/.config/hyde/wallbash/scripts/my-hyde-btop.sh" "$HOME/.config/hyde/wallbash/scripts/my-hyde-btop.sh" 0755
install_dot "$repo_dir/dotfiles/.local/bin/my-hyde-rofi-selection" "$HOME/.local/bin/my-hyde-rofi-selection" 0755

install_theme_files "LAGC Tech Dark"
install_theme_files "LAGC Tech Light"
install_kiro_theme
remove_target "$HOME/.config/hyde/wallbash/always/rofi-opaque.dcol"
remove_target "$HOME/.config/hyde/wallbash/theme/lagc-tech-dark-kitty.dcol"
remove_target "$HOME/.config/hyde/wallbash/always/lagc-tech-dark-waybar.dcol"
for stale_wallpaper in \
    "$HOME/.config/hyde/themes/LAGC Tech Dark/wallpapers/1-dark.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Dark/wallpapers/2-dark.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Dark/wallpapers/3-dark.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Light/wallpapers/1-light.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Light/wallpapers/2-light.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Light/wallpapers/3-light.png"; do
    remove_target "$stale_wallpaper"
done

theme_wallpaper="${MY_HYDE_WALLPAPER:-$HOME/Nextcloud/my_wallpapers/banner-ai-v4-painterly-companion.png}"
if [[ -f "$theme_wallpaper" ]]; then
    link_theme_wallpaper "LAGC Tech Dark" "$theme_wallpaper"
    link_theme_wallpaper "LAGC Tech Light" "$theme_wallpaper"
else
    printf 'LAGC Tech theme wallpapers were not linked; select a wallpaper first or set MY_HYDE_WALLPAPER when installing.\n' >&2
fi

if ! $dry_run; then
    "$HOME/.local/bin/my-hyde-qt-menu"
    hyde-shell waybar --set "$HOME/.config/waybar/layouts/my-hyde.jsonc"
    hyprctl reload >/dev/null 2>&1 || true
    systemctl --user restart hyde-Hyprland-idle.service

    wallpaper="${MY_HYDE_WALLPAPER:-$HOME/Nextcloud/my_wallpapers/banner-ai-v4-painterly-companion.png}"
    if [[ -f "$wallpaper" ]]; then
        hyde-shell wallpaper --set "$wallpaper" --global
    else
        printf 'Wallpaper not found, skipped: %s\n' "$wallpaper"
    fi

    hyprctl setcursor Future-cursors 42 >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface cursor-theme Future-cursors
    gsettings set org.gnome.desktop.interface cursor-size 42
    systemctl --user set-environment XCURSOR_THEME=Future-cursors XCURSOR_SIZE=42 HYPRCURSOR_THEME=Future-cursors HYPRCURSOR_SIZE=42
    dbus-update-activation-environment --systemd XCURSOR_THEME=Future-cursors XCURSOR_SIZE=42 HYPRCURSOR_THEME=Future-cursors HYPRCURSOR_SIZE=42

    printf 'Installed successfully. Backup: %s\n' "$backup_dir"
    printf 'Open a new terminal to load the restored Zsh environment.\n'
fi
