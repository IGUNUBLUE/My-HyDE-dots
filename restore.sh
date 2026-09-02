#!/usr/bin/env bash
set -Eeuo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/my-hyde-dots/backups"
backup=${1:-}

if [[ -z "$backup" ]]; then
    backup=$(find "$state_dir" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null | sort | tail -n 1)
fi

if [[ -z "$backup" || ! -d "$backup" ]]; then
    printf 'No backup found. Pass a backup directory explicitly.\n' >&2
    exit 1
fi

backup=$(realpath -- "$backup")
state_dir=$(realpath -- "$state_dir")
case "$backup" in
    "$state_dir"/*) ;;
    *) printf 'Refusing backup outside %s\n' "$state_dir" >&2; exit 1 ;;
esac

printf 'Restoring files from %s\n' "$backup"
if [[ -f "$backup/.created" ]]; then
    while IFS= read -r relative; do
        [[ -n "$relative" && "$relative" != /* && "$relative" != *'..'* ]] || {
            printf 'Unsafe entry in .created: %s\n' "$relative" >&2
            exit 1
        }
        rm -f -- "$HOME/$relative"
    done < "$backup/.created"
fi

while IFS= read -r -d '' source; do
    relative=${source#"$backup"/}
    target="$HOME/$relative"
    mkdir -p -- "$(dirname -- "$target")"
    cp -a -- "$source" "$target"
done < <(find "$backup" -type f ! -name .created -print0)

[[ -f "$HOME/.local/bin/hyde-brightness-panel" ]] && chmod 0755 "$HOME/.local/bin/hyde-brightness-panel"
hyde-shell waybar --update 2>/dev/null || true
hyprctl reload >/dev/null 2>&1 || true
printf 'Restore completed.\n'
