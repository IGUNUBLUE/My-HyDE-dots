#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

copy_dot() {
    local source=$1 destination=$2
    [[ -f "$source" ]] || { printf 'Missing source: %s\n' "$source" >&2; exit 1; }
    install -Dm0644 -- "$source" "$destination"
}

copy_theme() {
    local theme_name=$1 source_dir
    source_dir="$HOME/.config/hyde/themes/$theme_name"
    local source relative

    for source in hypr.theme kitty.theme rofi.theme theme.dcol waybar.theme; do
        copy_dot "$source_dir/$source" "$repo_dir/dotfiles/.config/hyde/themes/$theme_name/$source"
    done
}

mkdir -p "$repo_dir/dotfiles/.config/hyde"
sed "s|$HOME|@HOME@|g" "$HOME/.config/hyde/config.toml" > "$repo_dir/dotfiles/.config/hyde/config.toml.in"
copy_dot "$HOME/.config/environment.d/90-cursor-theme.conf" "$repo_dir/dotfiles/.config/environment.d/90-cursor-theme.conf"
copy_dot "$HOME/.icons/default/index.theme" "$repo_dir/dotfiles/.icons/default/index.theme"
copy_dot "$HOME/.local/share/icons/default/index.theme" "$repo_dir/dotfiles/.local/share/icons/default/index.theme"
copy_dot "$HOME/.config/hyde/wallbash/always/rofi-opaque.dcol" "$repo_dir/dotfiles/.config/hyde/wallbash/always/rofi-opaque.dcol"
copy_dot "$HOME/.local/bin/my-hyde-rofi-selection" "$repo_dir/dotfiles/.local/bin/my-hyde-rofi-selection"
chmod 0755 "$repo_dir/dotfiles/.local/bin/my-hyde-rofi-selection"
copy_theme "LAGC Tech Dark"
copy_theme "LAGC Tech Light"
copy_dot "$HOME/.config/zed/themes/lagc-tech.json" "$repo_dir/dotfiles/.config/zed/themes/lagc-tech.json"
copy_dot "$HOME/.config/hypr/hyprland.lua" "$repo_dir/dotfiles/.config/hypr/hyprland.lua"
copy_dot "$HOME/.config/hypr/hypridle.conf" "$repo_dir/dotfiles/.config/hypr/hypridle.conf"
copy_dot "$HOME/.config/waybar/layouts/my-hyde.jsonc" "$repo_dir/dotfiles/.config/waybar/layouts/my-hyde.jsonc"
copy_dot "$HOME/.config/waybar/modules/brightness-panel.jsonc" "$repo_dir/dotfiles/.config/waybar/modules/brightness-panel.jsonc"
copy_dot "$HOME/.config/waybar/user-style.css" "$repo_dir/dotfiles/.config/waybar/user-style.css"
copy_dot "$HOME/.config/kitty/kitty.conf" "$repo_dir/dotfiles/.config/kitty/kitty.conf"
copy_dot "$HOME/.config/zsh/user.zsh" "$repo_dir/dotfiles/.config/zsh/user.zsh"
copy_dot "$HOME/.local/bin/hyde-brightness-panel" "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel"
chmod 0755 "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel"
copy_dot "$HOME/.config/hyde/qt-menu.ini" "$repo_dir/dotfiles/.config/hyde/qt-menu.ini"
copy_dot "$HOME/.local/bin/my-hyde-qt-menu" "$repo_dir/dotfiles/.local/bin/my-hyde-qt-menu"
chmod 0755 "$repo_dir/dotfiles/.local/bin/my-hyde-qt-menu"

printf 'Snapshot updated. Review with: git diff\n'
