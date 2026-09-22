#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/my-hyde-dots"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$state_dir/backups/$timestamp"
install_log="$state_dir/install-$timestamp.log"
dry_run=false
skip_packages=false
assume_yes=false
qt_menu_only=false
vscodium_theme_only=false
only_modules=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--skip-packages] [--yes] [--only a,b] [--qt-menu-only] [--vscodium-theme-only]

Applies this personal overlay after an official HyDE installation.
Existing target files are backed up under ~/.local/state/my-hyde-dots/backups/.

  --dry-run            print actions without applying them
  --skip-packages      do not install packages.arch entries
  --yes                non-interactive: accept defaults, no prompts
  --only a,b           run only these modules: packages,cursor,config,themes,apply
  --qt-menu-only       refresh the Qt menu template and exit
  --vscodium-theme-only  reinstall the VSCodium LAGC themes and exit
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=true ;;
        --qt-menu-only) qt_menu_only=true; skip_packages=true ;;
        --vscodium-theme-only) vscodium_theme_only=true; skip_packages=true ;;
        --skip-packages) skip_packages=true ;;
        --yes|--non-interactive) assume_yes=true ;;
        --only) shift; only_modules=${1:-} ;;
        --only=*) only_modules=${1#--only=} ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Module selection
# ---------------------------------------------------------------------------
modules_all=(packages cursor config themes apply)
modules=("${modules_all[@]}")
if [[ -n "$only_modules" ]]; then
    modules=()
    IFS=',' read -ra requested <<< "$only_modules"
    for m in "${requested[@]}"; do
        case " ${modules_all[*]} " in
            *" $m "*) modules+=("$m") ;;
            *) printf 'Unknown module: %s\n' "$m" >&2; exit 2 ;;
        esac
    done
fi
$skip_packages && modules=("${modules[@]/packages}")

# Arrays do not survive `export` into the `gum spin -- bash -c` subshells, so
# membership is tracked as a comma-separated string instead.
compute_modules_csv() { MODULES_CSV=",$(IFS=,; echo "${modules[*]}"),"; }
compute_modules_csv

has_module() { [[ $MODULES_CSV == *",$1,"* ]]; }

# ---------------------------------------------------------------------------
# UI layer — clack-style chrome when gum + TTY are available, plain otherwise
# ---------------------------------------------------------------------------
sage='#A9C080'; amber='#D4A55C'; terracotta='#D67A6E'; muted='#8B8378'; ink='#E9DFCE'

interactive=false
if [[ -t 0 && -t 1 ]] && ! $dry_run && ! $assume_yes && ! $qt_menu_only && ! $vscodium_theme_only; then
    interactive=true
fi

if $interactive && ! command -v gum >/dev/null; then
    printf 'Para la experiencia interactiva se necesita gum (repo oficial Arch).\n'
    if sudo -v && sudo pacman -S --needed --noconfirm gum; then
        printf '\n'
    else
        interactive=false
    fi
fi
command -v gum >/dev/null 2>&1 || interactive=false

ui_bar()  { gum style --foreground "$muted" '│'; }
ui_head() { gum style --foreground "$amber" --bold '◆'; }
ui_step_done() { printf '%s %s\n' "$(gum style --foreground "$sage" '●')" "$(gum style --foreground "$ink" "$1")"; }
ui_step_fail() {
    printf '%s %s\n' "$(gum style --foreground "$terracotta" '◇')" "$(gum style --foreground "$terracotta" "$1")"
    gum style --foreground "$muted" "   ver log: $install_log"
}
ui_banner() {
    printf '\n%s\n%s\n%s\n%s\n' \
        "$(ui_head)  $(gum style --foreground "$ink" --bold 'My-HyDE-dots')" \
        "$(ui_bar)  $(gum style --foreground "$muted" 'overlay LAGC · HyDE')" \
        "$(ui_bar)  $(gum style --foreground "$muted" "log: $install_log")" \
        "$(ui_bar)"
}

ui_choose() { # ui_choose "pregunta" opt1 opt2…
    local question=$1; shift
    gum choose --header "$(gum style --foreground "$ink" "◇  $question")" \
        --header.foreground "$ink" \
        --cursor '●  ' --cursor.foreground "$sage" \
        --selected.foreground "$sage" --item.foreground "$muted" "$@"
}

ui_multiselect() { # ui_multiselect "pregunta" opt1 opt2…
    local question=$1; shift
    gum choose --no-limit --header "$(gum style --foreground "$ink" "◇  $question · espacio marca, enter confirma")" \
        --header.foreground "$ink" \
        --cursor '●  ' --cursor.foreground "$sage" \
        --selected.foreground "$sage" --item.foreground "$muted" "$@"
}

ui_confirm() { # ui_confirm "pregunta" [default_yes]
    local question=$1 affirmative='Sí'
    gum confirm "$question" --affirmative "$affirmative" --negative 'No' \
        --prompt.foreground "$ink" --selected.foreground "$sage"
}

ui_step() { # ui_step "Label" fn [stream]
    local label=$1 fn=$2 stream_flag=${3:-} rc
    if $interactive; then
        if [[ $stream_flag == stream ]]; then
            # Streaming keeps interactive commands (pacman prompts) visible:
            # output goes to the terminal AND the log at the same time.
            printf '%s\n' "$(gum style --foreground "$muted" "│  $label…")"
            if bash -ec "$fn" 2>&1 | tee -a "$install_log"; then rc=0; else rc=${PIPESTATUS[0]}; fi
        else
            if gum spin --spinner moon --spinner.foreground "$sage" \
                --title "$label" --title.foreground "$ink" \
                -- bash -ec "$fn" >>"$install_log" 2>&1; then rc=0; else rc=$?; fi
        fi
        if ((rc == 130)); then
            ui_bar
            gum style --foreground "$muted" '└  Cancelado por el usuario.'
            exit 130
        elif ((rc != 0)); then
            ui_step_fail "$label"
            exit 1
        fi
        ui_step_done "$label"
    else
        "$fn"
    fi
}

sudo_keepalive() {
    sudo -v || return 1
    ( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
}

# ---------------------------------------------------------------------------
# Core helpers (unchanged behavior)
# ---------------------------------------------------------------------------
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
        printf 'VSCodium CLI not found; LAGC VSCodium themes were not installed.\n' >&2
        $required && return 1
        return 0
    fi

    if $dry_run; then
        run python "$repo_dir/tools/package-vscodium-theme.py" --output "/tmp/igunublue.lagc-themes-0.1.0.vsix"
        run codium --install-extension "/tmp/igunublue.lagc-themes-0.1.0.vsix" --force
        return 0
    fi

    temporary_dir=$(mktemp -d)
    package="$temporary_dir/igunublue.lagc-themes-0.1.0.vsix"
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

# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------
step_packages() {
    local missing=() package
    while IFS= read -r package; do
        [[ -n "$package" && "$package" != \#* ]] || continue
        pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
    done < "$repo_dir/packages.arch"
    if ((${#missing[@]})); then
        run sudo pacman -S --needed "${missing[@]}"
    fi
}

step_cursor() {
    backup_cursor_state
    command -v hyprcursor-util >/dev/null || {
        printf 'hyprcursor-util is required to build the native Future-cyan cursor.\n' >&2
        return 1
    }
    local cursor_stage="$work_dir/Future-cursors"
    local cursor_build="$work_dir/hyprcursor-build"
    cp -a -- "$repo_dir/dotfiles/.local/share/icons/Future-cursors" "$cursor_stage"
    mkdir -p -- "$cursor_build"
    hyprcursor-util --create "$repo_dir/cursor-sources/Future-cyan-hyprcursor" --output "$cursor_build" >/dev/null
    cp -a -- "$cursor_build/theme_Future-cursors/manifest.hl" "$cursor_stage/manifest.hl"
    cp -a -- "$cursor_build/theme_Future-cursors/hyprcursors" "$cursor_stage/hyprcursors"
    cp -a -- "$repo_dir/cursor-sources/Future-cyan-hyprcursor/SOURCE.md" "$cursor_stage/HYPRCURSOR_SOURCE.md"

    install_tree "$cursor_stage" "$HOME/.local/share/icons/Future-cursors"
    install_dot "$repo_dir/dotfiles/.icons/default/index.theme" "$HOME/.icons/default/index.theme"
    install_dot "$repo_dir/dotfiles/.local/share/icons/default/index.theme" "$HOME/.local/share/icons/default/index.theme"
}

step_config() {
    install_dot "$work_dir/config.toml" "$HOME/.config/hyde/config.toml"
    install_dot "$repo_dir/dotfiles/.config/qt5ct/qt5ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"
    install_dot "$repo_dir/dotfiles/.config/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"
    install_dot "$repo_dir/dotfiles/.config/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"
    install_dot "$repo_dir/dotfiles/.config/environment.d/90-cursor-theme.conf" "$HOME/.config/environment.d/90-cursor-theme.conf"
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
    install_dot "$repo_dir/dotfiles/.local/bin/gtk3-cursor-fix" "$HOME/.local/bin/gtk3-cursor-fix" 0755
    install_dot "$repo_dir/dotfiles/.config/systemd/user/gtk3-cursor-fix.path" "$HOME/.config/systemd/user/gtk3-cursor-fix.path"
    install_dot "$repo_dir/dotfiles/.config/systemd/user/gtk3-cursor-fix.service" "$HOME/.config/systemd/user/gtk3-cursor-fix.service"
    install_dot "$repo_dir/dotfiles/.config/systemd/user/xsettingsd.service.d/10-restart.conf" "$HOME/.config/systemd/user/xsettingsd.service.d/10-restart.conf"
    install_qt_menu
}

step_themes() {
    install_theme_files "LAGC Tech Dark"
    install_theme_files "LAGC Tech Light"
    install_theme_files "LAGC Calm Dark"
    install_theme_files "LAGC Calm Light"
    install_vscodium_theme
    remove_target "$HOME/.config/hyde/wallbash/always/rofi-opaque.dcol"
    remove_target "$HOME/.config/hyde/wallbash/theme/lagc-tech-dark-kitty.dcol"
    remove_target "$HOME/.config/hyde/wallbash/always/lagc-tech-dark-waybar.dcol"
    local stale_wallpaper
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

    local theme_wallpaper="${MY_HYDE_WALLPAPER:-$HOME/Nextcloud/my_wallpapers/banner-ai-v4-painterly-companion.png}"
    if [[ -f "$theme_wallpaper" ]]; then
        generate_theme_wallpaper "LAGC Tech Dark" "$theme_wallpaper" dark
        generate_theme_wallpaper "LAGC Tech Light" "$theme_wallpaper" light
    else
        printf 'LAGC Tech theme wallpapers were not generated; select a wallpaper first or set MY_HYDE_WALLPAPER when installing.\n' >&2
    fi
    generate_calm_wallpaper "LAGC Calm Dark" dark
    generate_calm_wallpaper "LAGC Calm Light" light
}

step_apply() {
    if has_module config && [[ -x "$HOME/.local/bin/my-hyde-qt-menu" ]]; then
        "$HOME/.local/bin/my-hyde-qt-menu"
    fi
    if has_module config; then
        hyde-shell waybar --set "$HOME/.config/waybar/layouts/my-hyde.jsonc"
        hyprctl reload >/dev/null 2>&1 || true
        systemctl --user restart hyde-Hyprland-idle.service
        # HyDE's theme.switch writes xsettingsd.conf but nothing starts the
        # daemon; without it X11/XWayland clients never see live changes.
        systemctl --user add-wants graphical-session.target xsettingsd.service
        systemctl --user start xsettingsd.service 2>/dev/null || true

        # config.toml references Atkinson Hyperlegible Next static weights
        # (SemiBold for Waybar). They are not in the official repos, so install
        # them user-locally; offline failure is non-fatal (fontconfig falls
        # back to the packaged classic family or the default sans).
        local atkinson_dir="$HOME/.local/share/fonts/atkinson" weight
        local atkinson_base="https://raw.githubusercontent.com/googlefonts/atkinson-hyperlegible-next/main/fonts/ttf"
        mkdir -p "$atkinson_dir"
        for weight in Regular Medium SemiBold Bold Italic MediumItalic; do
            curl -fsSL --max-time 30 -o "$atkinson_dir/AtkinsonHyperlegibleNext-$weight.ttf" \
                "$atkinson_base/AtkinsonHyperlegibleNext-$weight.ttf" \
                || printf 'Atkinson Next %s download failed; fontconfig will fall back.\n' "$weight" >&2
        done
        fc-cache -f "$atkinson_dir" >/dev/null 2>&1 || true
        # Processes keep a stale fontconfig map until restarted; without this a
        # running swaync renders notification text as tofu after font install.
        systemctl --user restart swaync.service 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now gtk3-cursor-fix.path 2>/dev/null || true

        # GTK4/libadwaita read the interface font from gsettings (theme.switch
        # only writes gtk-3.0 settings.ini). Take family/size from config.toml's
        # [desktop.ui] so a fresh install matches the declared UI font.
        local ui_font ui_font_size
        ui_font=$(awk -F'"' '/^\[desktop\.ui\]/{s=1} s && /^font = /{print $2; exit}' "$HOME/.config/hyde/config.toml" 2>/dev/null)
        ui_font_size=$(awk -F'=[[:space:]]*' '/^\[desktop\.ui\]/{s=1} s && /^font_size = /{print $2; exit}' "$HOME/.config/hyde/config.toml" 2>/dev/null)
        [[ -n $ui_font ]] && gsettings set org.gnome.desktop.interface font-name "$ui_font ${ui_font_size:-11}"
    fi

    if has_module themes; then
        # Apply the ACTIVE theme's own wallpaper (its wall.set target), not the
        # Tech source image -- a global --set would rewrite the theme's link.
        local staterc="$HOME/.local/state/hyde/staterc" active_theme="" wall_set wallpaper
        [[ -f $staterc ]] && active_theme=$(awk -F'"' '/^HYDE_THEME=/{print $2}' "$staterc")
        wall_set="$HOME/.config/hyde/themes/$active_theme/wall.set"
        if [[ -n $active_theme && -e $wall_set ]]; then
            hyde-shell wallpaper --set "$(readlink -f "$wall_set")"
        else
            wallpaper="${MY_HYDE_WALLPAPER:-$HOME/Nextcloud/my_wallpapers/banner-ai-v4-painterly-companion.png}"
            if [[ -f $wallpaper ]]; then
                hyde-shell wallpaper --set "$wallpaper"
            else
                printf 'Wallpaper not found, skipped: %s\n' "$wallpaper"
            fi
        fi
    fi

    if has_module cursor; then
        hyprctl setcursor Future-cursors 46 >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface cursor-theme Future-cursors
        gsettings set org.gnome.desktop.interface cursor-size 32
        systemctl --user set-environment XCURSOR_THEME=Future-cursors XCURSOR_SIZE=32 HYPRCURSOR_THEME=Future-cursors HYPRCURSOR_SIZE=46
        dbus-update-activation-environment --systemd XCURSOR_THEME=Future-cursors XCURSOR_SIZE=32 HYPRCURSOR_THEME=Future-cursors HYPRCURSOR_SIZE=46
    fi
}

# ---------------------------------------------------------------------------
# Early exits and preflight
# ---------------------------------------------------------------------------
only_install_count=0
$qt_menu_only && ((only_install_count += 1))
$vscodium_theme_only && ((only_install_count += 1))
if ((only_install_count > 1)); then
    printf 'Use only one of --qt-menu-only or --vscodium-theme-only.\n' >&2
    exit 2
fi

if $vscodium_theme_only; then
    install_vscodium_theme true
    printf 'LAGC VSCodium themes installed. Select one with Preferences: Color Theme.\n'
    exit 0
fi

if [[ ! -f "$HOME/.local/share/hypr/hyde.lua" ]] || ! command -v hyde-shell >/dev/null; then
    printf 'HyDE is not installed. Install/update official HyDE first, then rerun this overlay.\n' >&2
    exit 1
fi

if $qt_menu_only; then
    install_qt_menu
    if ! $dry_run; then
        "$HOME/.local/bin/my-hyde-qt-menu"
        printf 'Qt menu preferences installed. Backup: %s\n' "$backup_dir"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Interactive flow
# ---------------------------------------------------------------------------
if $interactive; then
    mkdir -p "$state_dir"
    ui_banner

    mode=$(ui_choose '¿Qué instalar?' \
        'Todo (recomendado)' \
        'Solo temas' \
        'Solo cursor' \
        'Personalizado…') || { ui_bar; exit 0; }
    printf '%s\n' "$(gum style --foreground "$sage" '●')  $(gum style --foreground "$ink" "$mode")"
    ui_bar

    case "$mode" in
        'Solo temas')    modules=(themes apply) ;;
        'Solo cursor')   modules=(cursor apply) ;;
        'Personalizado…')
            mapfile -t picked < <(ui_multiselect 'Módulos:' \
                'Paquetes (pacman)' \
                'Cursor Future (hyprcursor)' \
                'Configs base (waybar, kitty, hooks)' \
                'Temas LAGC + wallpapers + VSCodium' \
                'Aplicar en vivo (reload, fuentes, envs)') || { ui_bar; exit 0; }
            modules=()
            for p in "${picked[@]}"; do
                case "$p" in
                    Paquetes*)     modules+=(packages) ;;
                    Cursor*)       modules+=(cursor) ;;
                    Configs*)      modules+=(config) ;;
                    Temas*)        modules+=(themes) ;;
                    Aplicar*)      modules+=(apply) ;;
                esac
            done
            ((${#modules[@]})) || { gum style --foreground "$muted" '└  Nada seleccionado.'; exit 0; }
            printf '%s\n' "$(gum style --foreground "$sage" '●')  $(gum style --foreground "$ink" "${picked[*]}")"
            ui_bar
            ;;
    esac
    compute_modules_csv

    if has_module packages; then
        if ui_confirm '¿Instalar paquetes de pacman?'; then
            printf '%s\n' "$(gum style --foreground "$sage" '●')  $(gum style --foreground "$ink" 'Paquetes: sí')"
        else
            modules=("${modules[@]/packages}")
            compute_modules_csv
            printf '%s\n' "$(gum style --foreground "$sage" '●')  $(gum style --foreground "$ink" 'Paquetes: no')"
        fi
        ui_bar
    fi

    if has_module packages; then
        sudo_keepalive || {
            gum style --foreground "$terracotta" '└  Sin sudo no se pueden instalar paquetes.'
            exit 1
        }
        ui_bar
    fi
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"; [[ -n ${SUDO_KEEPALIVE_PID:-} ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

config_tmp="$work_dir/config.toml"
sed "s|@HOME@|$HOME|g" "$repo_dir/dotfiles/.config/hyde/config.toml.in" > "$config_tmp"

export -f run backup_target install_dot install_tree backup_cursor_state \
    install_theme_files link_theme_wallpaper generate_theme_wallpaper \
    generate_calm_wallpaper remove_target install_qt_menu \
    install_vscodium_theme has_module step_packages step_cursor \
    step_config step_themes step_apply
export repo_dir backup_dir work_dir dry_run MODULES_CSV

$interactive && mkdir -p "$state_dir" && : > "$install_log"

has_module packages && ui_step 'Instalando paquetes' step_packages stream
has_module cursor   && ui_step 'Cursor Future compilado'   step_cursor
has_module config   && ui_step 'Configs aplicadas'         step_config
has_module themes   && ui_step 'Temas LAGC + wallpapers'   step_themes
has_module apply && ! $dry_run && ui_step 'Aplicado en vivo' step_apply

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if $interactive; then
    ui_bar
    printf '%s\n' "$(gum style --foreground "$muted" '└')  $(gum style --foreground "$sage" --bold '✔ Instalado')  $(gum style --foreground "$muted" "· backup en $backup_dir")"
    gum style --foreground "$muted" '   Abre una terminal nueva para cargar el entorno zsh.'
else
    printf 'Installed successfully. Backup: %s\n' "$backup_dir"
    printf 'Open a new terminal to load the restored Zsh environment.\n'
fi
