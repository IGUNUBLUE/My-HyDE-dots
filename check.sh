#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pycache_dir=$(mktemp -d)
trap 'rm -rf -- "$pycache_dir"' EXIT
[[ -s "$repo_dir/AGENTS.md" ]] || { printf 'AGENTS.md is missing or empty.\n' >&2; exit 1; }
bash -n "$repo_dir/install.sh" "$repo_dir/restore.sh" "$repo_dir/update-snapshot.sh" "$repo_dir/check.sh"
PYTHONPYCACHEPREFIX="$pycache_dir" python -m py_compile "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel"
python "$repo_dir/dotfiles/.local/bin/hyde-brightness-panel" --status | python -m json.tool >/dev/null

kitty_config="$repo_dir/dotfiles/.config/kitty/kitty.conf"
[[ -s "$kitty_config" ]] || { printf 'Kitty user configuration is missing or empty.\n' >&2; exit 1; }
[[ $(grep -Ec '^[[:space:]]*font_size[[:space:]]+11([.]0)?[[:space:]]*$' "$kitty_config") -eq 1 ]] || {
    printf 'Kitty must define the portable 11 pt default exactly once.\n' >&2
    exit 1
}
if find "$repo_dir/dotfiles/.config/kitty" -maxdepth 1 -type f \( -name 'hyde.conf' -o -name 'theme.conf' \) -print -quit | grep -q .; then
    printf 'HyDE-managed Kitty files must not be tracked.\n' >&2
    exit 1
fi

if rg -n -i '(BEGIN [A-Z ]*PRIVATE KEY|github_pat_|ghp_|api[_-]?key[[:space:]]*=|password[[:space:]]*=|token[[:space:]]*=)' "$repo_dir" --glob '!check.sh'; then
    printf 'Potential secret found. Refusing validation.\n' >&2
    exit 1
fi

printf 'All checks passed.\n'
