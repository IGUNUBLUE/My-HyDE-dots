#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/my-hyde-dots"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$state_dir/backups/$timestamp"
dry_run=false
skip_packages=false
qt_menu_only=false
vscodium_theme_only=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--skip-packages] [--qt-menu-only] [--vscodium-theme-only]

Applies this personal overlay after an official HyDE installation.
Existing target files are backed up under ~/.local/state/my-hyde-dots/backups/.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=true ;;
        --qt-menu-only) qt_menu_only=true; skip_packages=true ;;
        --vscodium-theme-only) vscodium_theme_only=true; skip_packages=true ;;
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

install_vscodium_theme() {
    local required=${1:-false} temporary_dir package

    if ! command -v codium >/dev/null; then
        printf 'VSCodium CLI not found; LAGC Calm VSCodium themes were not installed.\n' >&2
        $required && return 1
        return 0
    fi

    if $dry_run; then
        run python "$repo_dir/tools/package-vscodium-theme.py" --output "/tmp/igunublue.lagc-calm-themes-0.1.0.vsix"
        run codium --install-extension "/tmp/igunublue.lagc-calm-themes-0.1.0.vsix" --force
        return 0
    fi

    temporary_dir=$(mktemp -d)
    package="$temporary_dir/igunublue.lagc-calm-themes-0.1.0.vsix"
    if ! python "$repo_dir/tools/package-vscodium-theme.py" --output "$package"; then
        rm -rf -- "$temporary_dir"
        return 1
    fi
    if ! codium --install-extension "$package" --force; then
        rm -rf -- "$temporary_dir"
        return 1
    fi
    rm -rf -- "$temporary_dir"
}

only_install_count=0
$qt_menu_only && ((only_install_count += 1))
$vscodium_theme_only && ((only_install_count += 1))
if ((only_install_count > 1)); then
    printf 'Use only one of --qt-menu-only or --vscodium-theme-only.\n' >&2
    exit 2
fi

if $vscodium_theme_only; then
    install_vscodium_theme true
    printf 'LAGC Calm VSCodium themes installed. Select one with Preferences: Color Theme.\n'
    exit 0
fi

if [[ ! -f "$HOME/.local/share/hypr/hyde.lua" ]] || ! command -v hyde-shell >/dev/null; then
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

    if ! $dry_run && [[ ! -f "$wallpaper" ]]; then
        return 0
    fi
    if [[ ! -d "$wallpaper_dir" ]]; then
        backup_target "$wallpaper_dir"
        run mkdir -p -- "$wallpaper_dir"
    fi

    backup_target "$target"
    run rm -f -- "$target"
    run ln -s -- "$wallpaper" "$target"
}

generate_theme_wallpaper() {
    local theme_name=$1 source=$2 variant=$3
    local wallpaper_dir target
    wallpaper_dir="$HOME/.config/hyde/themes/$theme_name/wallpapers"
    target="$wallpaper_dir/lagc-tech-$variant.png"

    if [[ ! -d "$wallpaper_dir" ]]; then
        backup_target "$wallpaper_dir"
        run mkdir -p -- "$wallpaper_dir"
    fi
    backup_target "$target"

    case "$variant" in
        dark)
            run magick "$source" -auto-orient -strip -resize '3840x2160>' -colorspace sRGB \
                -fill '#061B2B' -colorize 30 -modulate 88,105,100 "$target"
            ;;
        light)
            run magick "$source" -auto-orient -strip -resize '3840x2160>' -colorspace sRGB \
                -fill '#EAFBFF' -colorize 36 -modulate 108,92,100 "$target"
            ;;
        *)
            printf 'Unknown LAGC Tech wallpaper variant: %s\n' "$variant" >&2
            return 1
            ;;
    esac

    link_theme_wallpaper "$theme_name" "$target"
    # Cache only the generated image. Caching the whole theme also walks every
    # configured custom wallpaper path, which can be unnecessarily expensive.
    run hyde-shell wallpaper --cache wall "$target"
}

generate_calm_wallpaper() {
    local theme_name=$1 variant=$2
    local wallpaper_dir target url
    wallpaper_dir="$HOME/.config/hyde/themes/$theme_name/wallpapers"
    target="$wallpaper_dir/lagc-calm-$variant.jpg"

    case "$variant" in
        # Warm low-glare photos matching each palette; fall back to a
        # deterministic gradient when offline so installs never fail.
        dark)  url="https://w.wallhaven.cc/full/7j/wallhaven-7jwx8v.jpg" ;;
        light) url="https://w.wallhaven.cc/full/ly/wallhaven-ly8xwr.jpg" ;;
        *)
            printf 'Unknown LAGC Calm wallpaper variant: %s\n' "$variant" >&2
            return 1
            ;;
    esac

    if [[ ! -d "$wallpaper_dir" ]]; then
        backup_target "$wallpaper_dir"
        run mkdir -p -- "$wallpaper_dir"
    fi
    backup_target "$target"

    if ! $dry_run && curl -fsSL --max-time 30 -o "$target" "$url" && [[ -s "$target" ]]; then
        run magick "$target" -resize '3840x2160>' -strip -quality 92 "$target"
    elif [[ "$variant" == dark ]]; then
        run magick -size 1920x1080 gradient:'#332C26'-'#211D1B' \
            \( -size 1920x1080 xc:black -fill '#A9C080' \
            -draw 'ellipse 1520,180 760,480 0,360' -blur 0x280 -evaluate multiply 0.10 \) \
            -compose screen -composite "${target%.jpg}.png"
        target="${target%.jpg}.png"
    else
        run magick -size 1920x1080 gradient:'#F4EEE2'-'#E2D7C4' \
            \( -size 1920x1080 xc:black -fill '#DDE7C8' \
            -draw 'ellipse 1520,180 760,480 0,360' -blur 0x280 -evaluate multiply 0.45 \) \
            -compose screen -composite "${target%.jpg}.png"
        target="${target%.jpg}.png"
    fi

    link_theme_wallpaper "$theme_name" "$target"
    run hyde-shell wallpaper --cache wall "$target"
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
install_dot "$repo_dir/dotfiles/.config/qt5ct/qt5ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"
install_dot "$repo_dir/dotfiles/.config/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"
install_dot "$repo_dir/dotfiles/.config/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"
install_dot "$repo_dir/dotfiles/.config/environment.d/90-cursor-theme.conf" "$HOME/.config/environment.d/90-cursor-theme.conf"
install_tree "$cursor_stage" "$HOME/.local/share/icons/Future-cursors"
install_dot "$repo_dir/dotfiles/.icons/default/index.theme" "$HOME/.icons/default/index.theme"
install_dot "$repo_dir/dotfiles/.local/share/icons/default/index.theme" "$HOME/.local/share/icons/default/index.theme"
install_dot "$repo_dir/dotfiles/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
install_dot "$repo_dir/dotfiles/.config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
install_dot "$repo_dir/dotfiles/.config/waybar/layouts/my-hyde.jsonc" "$HOME/.config/waybar/layouts/my-hyde.jsonc"
install_dot "$repo_dir/dotfiles/.config/waybar/modules/brightness-panel.jsonc" "$HOME/.config/waybar/modules/brightness-panel.jsonc"
install_dot "$repo_dir/dotfiles/.config/waybar/user-style.css" "$HOME/.config/waybar/user-style.css"
install_dot "$repo_dir/dotfiles/.config/swaync/user-style.css" "$HOME/.config/swaync/user-style.css"
install_dot "$repo_dir/dotfiles/.config/wlogout/style_1.css" "$HOME/.config/wlogout/style_1.css"
install_dot "$repo_dir/dotfiles/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
install_dot "$repo_dir/dotfiles/.config/zsh/user.zsh" "$HOME/.config/zsh/user.zsh"
install_dot "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel" "$HOME/.local/bin/hyde-brightness-panel" 0755
install_dot "$repo_dir/dotfiles/.config/hyde/wallbash/always/rofi-frosted.dcol" "$HOME/.config/hyde/wallbash/always/rofi-frosted.dcol"
install_dot "$repo_dir/dotfiles/.config/hyde/wallbash/always/btop.dcol" "$HOME/.config/hyde/wallbash/always/btop.dcol"
install_dot "$repo_dir/dotfiles/.config/hyde/wallbash/scripts/my-hyde-btop.sh" "$HOME/.config/hyde/wallbash/scripts/my-hyde-btop.sh" 0755
install_dot "$repo_dir/dotfiles/.local/bin/my-hyde-rofi-selection" "$HOME/.local/bin/my-hyde-rofi-selection" 0755

install_theme_files "LAGC Tech Dark"
install_theme_files "LAGC Tech Light"
install_theme_files "LAGC Calm Dark"
install_theme_files "LAGC Calm Light"
install_vscodium_theme
remove_target "$HOME/.config/hyde/wallbash/always/rofi-opaque.dcol"
remove_target "$HOME/.config/hyde/wallbash/theme/lagc-tech-dark-kitty.dcol"
remove_target "$HOME/.config/hyde/wallbash/always/lagc-tech-dark-waybar.dcol"
for stale_wallpaper in \
    "$HOME/.config/hyde/themes/LAGC Tech Dark/wallpapers/1-dark.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Dark/wallpapers/2-dark.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Dark/wallpapers/3-dark.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Dark/wallpapers/lagc-tech-wallpaper.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Light/wallpapers/1-light.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Light/wallpapers/2-light.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Light/wallpapers/3-light.png" \
    "$HOME/.config/hyde/themes/LAGC Tech Light/wallpapers/lagc-tech-wallpaper.png"; do
    remove_target "$stale_wallpaper"
done

theme_wallpaper="${MY_HYDE_WALLPAPER:-$HOME/Nextcloud/my_wallpapers/banner-ai-v4-painterly-companion.png}"
if [[ -f "$theme_wallpaper" ]]; then
    generate_theme_wallpaper "LAGC Tech Dark" "$theme_wallpaper" dark
    generate_theme_wallpaper "LAGC Tech Light" "$theme_wallpaper" light
else
    printf 'LAGC Tech theme wallpapers were not generated; select a wallpaper first or set MY_HYDE_WALLPAPER when installing.\n' >&2
fi

generate_calm_wallpaper "LAGC Calm Dark" dark
generate_calm_wallpaper "LAGC Calm Light" light

if ! $dry_run; then
    "$HOME/.local/bin/my-hyde-qt-menu"
    hyde-shell waybar --set "$HOME/.config/waybar/layouts/my-hyde.jsonc"
    hyprctl reload >/dev/null 2>&1 || true
    systemctl --user restart hyde-Hyprland-idle.service
    # HyDE's theme.switch writes xsettingsd.conf but nothing starts the daemon;
    # without it X11/XWayland clients never see live icon/theme changes.
    systemctl --user add-wants graphical-session.target xsettingsd.service
    systemctl --user start xsettingsd.service 2>/dev/null || true

    # config.toml references Atkinson Hyperlegible Next static weights
    # (Medium UI, SemiBold Waybar). They are not in the official repos, so
    # install them user-locally; offline failure is non-fatal (fontconfig
    # falls back to the packaged classic family or the default sans).
    atkinson_dir="$HOME/.local/share/fonts/atkinson"
    mkdir -p "$atkinson_dir"
    atkinson_base="https://raw.githubusercontent.com/googlefonts/atkinson-hyperlegible-next/main/fonts/ttf"
    for weight in Regular Medium SemiBold Bold Italic MediumItalic; do
        curl -fsSL --max-time 30 -o "$atkinson_dir/AtkinsonHyperlegibleNext-$weight.ttf" \
            "$atkinson_base/AtkinsonHyperlegibleNext-$weight.ttf" \
            || printf 'Atkinson Next %s download failed; fontconfig will fall back.\n' "$weight" >&2
    done
    fc-cache -f "$atkinson_dir" >/dev/null 2>&1 || true
    # Processes keep a stale fontconfig map until restarted; without this a
    # running swaync renders notification text as tofu after font install.
    systemctl --user restart swaync.service 2>/dev/null || true

    wallpaper="${MY_HYDE_WALLPAPER:-$HOME/Nextcloud/my_wallpapers/banner-ai-v4-painterly-companion.png}"
    if [[ -f "$wallpaper" ]]; then
        hyde-shell wallpaper --set "$wallpaper" --global
    else
        printf 'Wallpaper not found, skipped: %s\n' "$wallpaper"
    fi

    hyprctl setcursor Future-cursors 46 >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface cursor-theme Future-cursors
    gsettings set org.gnome.desktop.interface cursor-size 46
    systemctl --user set-environment XCURSOR_THEME=Future-cursors XCURSOR_SIZE=46 HYPRCURSOR_THEME=Future-cursors HYPRCURSOR_SIZE=46
    dbus-update-activation-environment --systemd XCURSOR_THEME=Future-cursors XCURSOR_SIZE=46 HYPRCURSOR_THEME=Future-cursors HYPRCURSOR_SIZE=46

    printf 'Installed successfully. Backup: %s\n' "$backup_dir"
    printf 'Open a new terminal to load the restored Zsh environment.\n'
fi
