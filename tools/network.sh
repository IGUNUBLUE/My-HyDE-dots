# Sourced by install.sh; use its run/backup helpers and dry-run policy.
network_gui() {
    command -v networkmanager_dmenu
}

require_network_gui() {
    $dry_run && return 0
    local gui
    gui=$(network_gui) || {
        printf 'Install networkmanager-dmenu first: ./install.sh --network-only\n' >&2
        return 1
    }
    "$gui" --version || return 1
    rofi -version
}

install_network_packages() {
    local missing=() package
    for package in networkmanager networkmanager-dmenu rofi; do
        pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
    done
    ((${#missing[@]})) || return 0
    local options=(-S --needed)
    $assume_yes && options+=(--noconfirm)
    run sudo pacman "${options[@]}" "${missing[@]}"
}

remove_old_network_config() {
    # Exact prior overlay assets only; never remove the nmrs preference tree.
    local relative
    for relative in \
        .config/waybar/modules/network-nmrs.jsonc \
        .config/waybar/modules/network-menu.jsonc \
        .config/hyde/wallbash/always/nmrs.dcol \
        .config/hyde/wallbash/scripts/my-hyde-nmrs-theme.sh \
        .local/share/applications/nmrs.desktop \
        .local/share/icons/hicolor/scalable/apps/org.nmrs.ui.svg \
        .config/nmrs/base.css .config/nmrs/style.css .config/nmrs/theme \
        .config/nmrs/LICENSE-MIT .config/nmrs/SOURCE.md \
        .config/nmrs/themes/lagc-calm-dark.css .config/nmrs/themes/lagc-calm-light.css \
        .config/nmrs/themes/lagc-tech-dark.css .config/nmrs/themes/lagc-tech-light.css; do
        remove_target "$HOME/$relative"
    done
}

install_network_config() {
    install_dot "$repo_dir/dotfiles/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
    install_dot "$repo_dir/dotfiles/.config/waybar/layouts/my-hyde.jsonc" "$HOME/.config/waybar/layouts/my-hyde.jsonc"
    install_dot "$repo_dir/dotfiles/.config/waybar/modules/network-connections.jsonc" "$HOME/.config/waybar/modules/network-connections.jsonc"
    install_dot "$repo_dir/dotfiles/.config/autostart/nm-applet.desktop" "$HOME/.config/autostart/nm-applet.desktop"
    install_dot "$repo_dir/dotfiles/.local/bin/my-hyde-network-status" "$HOME/.local/bin/my-hyde-network-status" 0755
    install_dot "$repo_dir/dotfiles/.local/bin/my-hyde-network" "$HOME/.local/bin/my-hyde-network" 0755
    install_dot "$repo_dir/dotfiles/.config/rofi/network.rasi" "$HOME/.config/rofi/network.rasi"
    local relative stage
    for relative in .config/networkmanager-dmenu/config.ini .local/share/applications/networkmanager_dmenu.desktop; do
        stage=$(mktemp)
        sed "s|@HOME@|$HOME|g" "$repo_dir/dotfiles/$relative.in" > "$stage"
        install_dot "$stage" "$HOME/$relative"
        rm -f -- "$stage"
    done
    remove_old_network_config
    if ! $dry_run && command -v update-desktop-database >/dev/null; then
        update-desktop-database "$HOME/.local/share/applications"
    fi
}

apply_network_config() {
    systemctl --user daemon-reload
    hyprctl reload
    local errors
    errors=$(hyprctl configerrors) || return 1
    [[ -z "$errors" ]] || { printf '%s\n' "$errors" >&2; return 1; }
    hyde-shell waybar --set "$HOME/.config/waybar/layouts/my-hyde.jsonc"
    systemctl --user stop 'app-nm\x2dapplet@autostart.service' \
        hyde-Hyprland-network-manager-applet.service 2>/dev/null || true
    pkill -u "$(id -u)" -x nm-applet 2>/dev/null || true
}

remove_legacy_network_applet() {
    # Explicit owner-requested frontend replacements. No recursive removal.
    local package plan
    for package in network-manager-applet nmrs; do
        pacman -Q "$package" >/dev/null 2>&1 || continue
        plan=$(pacman -R --print --print-format '%n' "$package") || return 1
        [[ "$plan" == "$package" ]] || {
            printf 'Refusing unexpected network GUI removal plan: %s\n' "$plan" >&2
            return 1
        }
        if ! $dry_run; then
            require_network_gui || return 1
            mkdir -p "$backup_dir"
            pacman -Q "$package" >> "$backup_dir/.network-package-state"
        fi
        local options=(-R)
        $assume_yes && options+=(--noconfirm)
        run sudo pacman "${options[@]}" "$package"
    done
}
