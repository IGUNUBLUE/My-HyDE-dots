# LAGC Calm theme pair, Atkinson Hyperlegible, and static theme.dcol palettes

- Status: active
- Date: 2026-09-21
- Scope: HyDE themes, fonts, GTK/icons, theme switching, install.sh, check.sh
- Sources: Solarized/Everforest low-glare research, HyDE `theme.switch.sh`/`.dcol` hook inspection, WCAG contrast measurements, live theme-cycle verification

## Context

The user asked for an eye-friendly theme and reported that theme switches looked partially applied (icons and colors stale). Research pointed to warm low-glare palettes (Solarized/Everforest lineage): stepped warm-neutral surfaces, medium text contrast, one interactive accent, attention colors reserved for semantics. Diagnosis showed most official HyDE themes ship no `theme.dcol`, so Wallbash derives `colors.conf`, Waybar, Rofi, Swaync and Qt colors from the wallpaper while `kitty.theme`/`hypr.theme` keep fixed colors — two coexisting palettes per theme.

## Evidence

Verified 2026-09-21 on the live machine: `theme.switch.sh` consumed the Calm `theme.dcol` files (log: "apply dark/light colors :: LAGC Calm … theme"), `colors.conf` carried the fixed palette (`pry1=2B2522`/`F4EEE2`), and rofi/waybar/swaync/kitty regenerated from the same tokens across a Light→Dark→Light cycle. `hyprctl configerrors` stayed empty and cursor aliases remained `Future-cursors`. Official themes such as Rosé Pine lack `theme.dcol`; their generated colors came from the wallpaper (e.g. `main-bg #312830`) while `kitty.theme` used the canonical palette — the reported mismatch.

## Decision

Ship `LAGC Calm Dark` (`.sort` 11) and `LAGC Calm Light` (`.sort` 12) with static `theme.dcol` palettes. Dark: base `#2B2522`, text `#E9DFCE`, sage `#A9C080`/`#8FA66B`, amber `#D4A55C`, terracotta `#D67A6E`, muted `#B5A796`; `Gruvbox-Retro` GTK + `Tela-circle-yellow` icons. Light: base `#F4EEE2`, ink `#3A342C`, olive `#5C7040`/`#6B7F4E`, amber `#8A5A1E`, brick `#9E4F43`, muted `#6B6154`; `adw-gtk3` GTK + `Tela-circle-yellow`. All state/interactive colors meet WCAG AA >= 4.5:1 on `main-bg`. Both `hypr.theme` files declare `$CURSOR_THEME=Future-cursors` and `$CURSOR_SIZE=42` per the 2026-09-19 decision.

`Atkinson Hyperlegible` (package `ttf-atkinson-hyperlegible`) backs `[waybar]`, `[desktop.ui]`, `[gtk3]`, `[qt5]`, `[qt6]`, and `[notification]` font keys in `config.toml`; HyDE applies fonts globally so this also affects LAGC Tech. `CaskaydiaCove Nerd Font Mono` remains monospace. `install.sh` generates both wallpapers deterministically via `generate_calm_wallpaper` (ImageMagick gradients; no committed binary, no external source). `wall.hyprlock.png` stays a manual symlink convention; HyDE reads `~/.cache/hyde/wallpapers/hyprlock.png`.

Reload coverage after a switch: live via `.dcol` hooks — kitty, Waybar, Swaync, Rofi, Hyprland, Hyprlock, Dunst, qtct/Kvantum. Needs restart or extra tooling — GTK2/3 and Qt apps, VS Code (`code.dcol` output consumed only by a Wallbash-aware theme), vim, Discord (BetterDiscord), Spotify (spicetify). Dark/light only via `prefers-color-scheme` — Slack, browsers, Electron. TUIs inside kitty inherit the palette live.

## Validation

`./check.sh`, `./install.sh --dry-run --skip-packages`, and `git diff --check` clean; live cycle verified consistent generated artifacts and `hyprctl configerrors` empty on both modes.

## Exit criteria

Revert by deleting the two theme directories, restoring `config.toml` font keys to `Noto Sans Medium`/`Noto Sans SemiBold`, and re-running `theme.switch.sh`; `git checkout` restores tracked state.
