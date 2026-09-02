#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/my-hyde-dots"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$state_dir/backups/$timestamp"
dry_run=false
skip_packages=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--skip-packages]

Applies this personal overlay after an official HyDE installation.
Existing target files are backed up under ~/.local/state/my-hyde-dots/backups/.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=true ;;
        --skip-packages) skip_packages=true ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ ! -f "$HOME/.local/share/hypr/hyde.lua" ]] || ! command -v hyde-shell >/dev/null; then
    printf 'HyDE is not installed. Install/update official HyDE first, then rerun this overlay.\n' >&2
    exit 1
fi

run() {
    if $dry_run; then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
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
    run mkdir -p "$backup_dir/$(dirname -- "$relative")"
    run cp -a -- "$target" "$backup_dir/$relative"
}

install_dot() {
    local source=$1 target=$2 mode=${3:-0644}
    backup_target "$target"
    run install -Dm"$mode" -- "$source" "$target"
}

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

config_source="$repo_dir/dotfiles/.config/hyde/config.toml.in"
config_tmp=$(mktemp)
trap 'rm -f -- "$config_tmp"' EXIT
sed "s|@HOME@|$HOME|g" "$config_source" > "$config_tmp"

install_dot "$config_tmp" "$HOME/.config/hyde/config.toml"
install_dot "$repo_dir/dotfiles/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
install_dot "$repo_dir/dotfiles/.config/waybar/layouts/my-hyde.jsonc" "$HOME/.config/waybar/layouts/my-hyde.jsonc"
install_dot "$repo_dir/dotfiles/.config/waybar/modules/brightness-panel.jsonc" "$HOME/.config/waybar/modules/brightness-panel.jsonc"
install_dot "$repo_dir/dotfiles/.config/waybar/user-style.css" "$HOME/.config/waybar/user-style.css"
install_dot "$repo_dir/dotfiles/.config/zsh/user.zsh" "$HOME/.config/zsh/user.zsh"
install_dot "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel" "$HOME/.local/bin/hyde-brightness-panel" 0755

if ! $dry_run; then
    hyde-shell waybar --set "$HOME/.config/waybar/layouts/my-hyde.jsonc"
    hyprctl reload >/dev/null 2>&1 || true

    wallpaper="${MY_HYDE_WALLPAPER:-$HOME/Nextcloud/my_wallpapers/banner-ai-v4-painterly-companion.png}"
    if [[ -f "$wallpaper" ]]; then
        hyde-shell wallpaper --set "$wallpaper" --global
    else
        printf 'Wallpaper not found, skipped: %s\n' "$wallpaper"
    fi

    printf 'Installed successfully. Backup: %s\n' "$backup_dir"
    printf 'Open a new terminal to load the restored Zsh environment.\n'
fi
