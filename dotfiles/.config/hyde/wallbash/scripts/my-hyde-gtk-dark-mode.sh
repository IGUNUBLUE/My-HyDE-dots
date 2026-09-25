#!/usr/bin/env bash
# HyDE rewrites gtk-3.0/settings.ini on every theme switch but never sets
# gtk-application-prefer-dark-theme. GTK3 clients — including Chromium in
# "Use GTK" mode — read that key to pick their light/dark variant, so a stale
# 0 keeps them light on dark themes. Pin it to the active wallbash mode.
set -Eeuo pipefail

conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
marker="$conf_dir/.wallbash-dark-mode"
ini="$conf_dir/settings.ini"

[[ -f $marker ]] || exit 0
mode=$(tr -d '[:space:]' < "$marker")
case "$mode" in
    dark)  want=1 ;;
    light) want=0 ;;
    *) exit 0 ;;
esac

if [[ -f $ini ]]; then
    old=$(awk -F= '/^[[:space:]]*gtk-application-prefer-dark-theme[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' "$ini")
else
    mkdir -p "$conf_dir"
    old=""
fi

if [[ -n $old ]]; then
    [[ $old == "$want" ]] && exit 0
    sed -i "s|^[[:space:]]*gtk-application-prefer-dark-theme[[:space:]]*=.*$|gtk-application-prefer-dark-theme=$want|" "$ini"
elif [[ -f $ini ]]; then
    if grep -q '^\[Settings\]' "$ini"; then
        sed -i "s|^\[Settings\].*$|&\ngtk-application-prefer-dark-theme=$want|" "$ini"
    else
        printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$want" >> "$ini"
    fi
else
    printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$want" > "$ini"
fi

# Chromium caches GtkSettings; re-emitting gtk-theme makes GTK-mode browsers
# pick up the new preference without a restart.
command -v gsettings >/dev/null 2>&1 || exit 0
gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null) || exit 0
[[ -n $gtk_theme ]] || exit 0
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' 2>/dev/null || exit 0
sleep 0.2
gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true

exit 0
