#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

copy_dot() {
    local source=$1 destination=$2
    [[ -f "$source" ]] || { printf 'Missing source: %s\n' "$source" >&2; exit 1; }
    install -Dm0644 -- "$source" "$destination"
}

mkdir -p "$repo_dir/dotfiles/.config/hyde"
sed "s|$HOME|@HOME@|g" "$HOME/.config/hyde/config.toml" > "$repo_dir/dotfiles/.config/hyde/config.toml.in"
copy_dot "$HOME/.config/hypr/hyprland.lua" "$repo_dir/dotfiles/.config/hypr/hyprland.lua"
copy_dot "$HOME/.config/waybar/layouts/my-hyde.jsonc" "$repo_dir/dotfiles/.config/waybar/layouts/my-hyde.jsonc"
copy_dot "$HOME/.config/waybar/modules/brightness-panel.jsonc" "$repo_dir/dotfiles/.config/waybar/modules/brightness-panel.jsonc"
copy_dot "$HOME/.config/waybar/user-style.css" "$repo_dir/dotfiles/.config/waybar/user-style.css"
copy_dot "$HOME/.config/kitty/kitty.conf" "$repo_dir/dotfiles/.config/kitty/kitty.conf"
copy_dot "$HOME/.config/zsh/user.zsh" "$repo_dir/dotfiles/.config/zsh/user.zsh"
copy_dot "$HOME/.local/bin/hyde-brightness-panel" "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel"
chmod 0755 "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel"

printf 'Snapshot updated. Review with: git diff\n'
