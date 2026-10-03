#!/usr/bin/env bash
# Keeps GTK clients — including Chrome/Brave in "Use GTK" mode and Firefox —
# in step with every HyDE theme switch.
#
# 1. HyDE rewrites gtk-3.0/settings.ini on every switch but never sets
#    gtk-application-prefer-dark-theme, which GTK3 clients read to pick their
#    light/dark variant. Pin it to the active wallbash mode.
# 2. Wallbash rewrites Wallbash-Gtk's gtk.css in place, and gtk3.dcol/gtk4.dcol
#    copy it to gtk-dark.css in the background. The theme *name* never changes,
#    so running GTK clients keep the old css even on a dark->dark switch, and
#    theme.switch.sh's earlier xsettings/icon changes can make them reload
#    before the new css exists. Once both css copies agree, re-emit gtk-theme
#    so every client re-reads the finished theme. This runs on every switch.
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
    [[ $old == "$want" ]] || sed -i "s|^[[:space:]]*gtk-application-prefer-dark-theme[[:space:]]*=.*$|gtk-application-prefer-dark-theme=$want|" "$ini"
elif [[ -f $ini ]]; then
    if grep -q '^\[Settings\]' "$ini"; then
        sed -i "s|^\[Settings\].*$|&\ngtk-application-prefer-dark-theme=$want|" "$ini"
    else
        printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$want" >> "$ini"
    fi
else
    printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$want" > "$ini"
fi

command -v gsettings >/dev/null 2>&1 || exit 0
gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'") || exit 0
[[ -n $gtk_theme ]] || exit 0

# Wait (bounded) until the background gtk-dark.css copies match gtk.css, so a
# dark-variant client never reloads a stale copy.
theme_dir="${XDG_DATA_HOME:-$HOME/.local/share}/themes/$gtk_theme"
settle=${MY_HYDE_GTK_SETTLE:-3}
deadline=$(( $(date +%s%N) + settle * 1000000000 ))
for version in gtk-3.0 gtk-4.0; do
    css="$theme_dir/$version/gtk.css" dark="$theme_dir/$version/gtk-dark.css"
    [[ -f $css && -f $dark ]] || continue
    until cmp -s -- "$css" "$dark" || (( $(date +%s%N) >= deadline )); do
        sleep 0.1
    done
done

# Re-emit: switching to another theme name and back makes GTK reload the css.
# Firefox can drop the second of two quick changes and stay on the first one,
# so the first name is an alias of the same theme (a symlink created on
# demand): a client that stops there still renders the finished palette.
themes_root="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
placeholder="$gtk_theme-reload"
if [[ -d $theme_dir ]]; then
    [[ -L $themes_root/$placeholder || ! -e $themes_root/$placeholder ]] &&
        ln -sfn -- "$gtk_theme" "$themes_root/$placeholder"
else
    placeholder=adw-gtk3   # theme not in the user dir: plain toggle
    [[ $gtk_theme == "$placeholder" ]] && placeholder=Adwaita
fi
gsettings set org.gnome.desktop.interface gtk-theme "$placeholder" 2>/dev/null || exit 0
sleep "${MY_HYDE_GTK_GAP:-1}"
gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true

exit 0
