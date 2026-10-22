# Sourced by install.sh. Only declared presentation preferences are merged.
install_herdr_theme() (
    command -v herdr >/dev/null || { printf 'Herdr not installed; skipping optional appearance settings.\n'; return 0; }
    theme_stage=$(mktemp)
    radar_stage=$(mktemp)
    trap 'rm -f -- "$theme_stage" "$radar_stage"' EXIT
    theme_target="$HOME/.config/herdr/config.toml"
    radar_target="$HOME/.config/herdr/plugins/config/hhdebb.herdr-radar/config.toml"
    python "$repo_dir/tools/merge-toml-overlay.py" "$theme_target" \
        "$repo_dir/dotfiles/.config/hyde/herdr-theme.toml" "$theme_stage"
    python "$repo_dir/tools/merge-toml-overlay.py" "$radar_target" \
        "$repo_dir/dotfiles/.config/hyde/herdr-radar.toml" "$radar_stage"
    HERDR_CONFIG_PATH="$theme_stage" herdr config check
    for kind in theme radar; do
        if [[ $kind == theme ]]; then target=$theme_target; stage=$theme_stage; else target=$radar_target; stage=$radar_stage; fi
        mode=0644
        [[ ! -f "$target" ]] || mode=$(stat -c '%a' "$target")
        install_dot "$stage" "$target" "$mode"
    done
    if ! $dry_run; then
        if herdr status server 2>/dev/null | grep -q 'status: running'; then
            herdr server reload-config
        else
            printf 'Herdr is not running; preferences apply on its next start.\n'
        fi
    fi
)
