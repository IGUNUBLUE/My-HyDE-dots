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

`Atkinson Hyperlegible Next` backs the font keys in `config.toml`: Medium for `[desktop.ui]`/`[gtk3]`/`[qt5]`/`[qt6]`/`[notification]`/document and SemiBold for `[waybar]`. The classic family (`ttf-atkinson-hyperlegible`) ships only Regular/Bold — the first drop to weight 400 read noticeably thin on light surfaces, so `install.sh` vendors the upstream static Next weights into `~/.local/share/fonts/atkinson` (offline failure falls back through fontconfig). The qualified names (`Atkinson Hyperlegible Next Medium`) resolve through fontconfig, Pango, Qt and Waybar's `font-family` exactly like `Noto Sans Medium` did. HyDE applies fonts globally so this also affects LAGC Tech. `CaskaydiaCove Nerd Font Mono` remains monospace. `install.sh` fetches each Calm wallpaper from Wallhaven (dark `7jwx8v`, originally Flickr peste76; light `ly8xwr`, originally Unsplash `m1Jnyio2pUs`) and falls back to a deterministic ImageMagick gradient when offline; no wallpaper binary is committed. `wall.hyprlock.png` stays a manual symlink convention; HyDE reads `~/.cache/hyde/wallpapers/hyprlock.png`.

Reload coverage after a switch: live via `.dcol` hooks — kitty, Waybar, Swaync, Rofi, Hyprland, Hyprlock, Dunst, qtct/Kvantum. Needs restart or extra tooling — GTK2/3 and Qt apps, VS Code (`code.dcol` output consumed only by a Wallbash-aware theme), vim, Discord (BetterDiscord), Spotify (spicetify). Dark/light only via `prefers-color-scheme` — Slack, browsers, Electron. TUIs inside kitty inherit the palette live.

Separate gap found during the same audit: `theme.switch.sh` writes `~/.config/xsettingsd/xsettingsd.conf` but nothing in HyDE starts or reloads `xsettingsd`, and no XSETTINGS provider was running. X11/XWayland clients therefore never receive live icon/theme/cursor changes. `install.sh` now pulls `xsettingsd.service` into `graphical-session.target.wants` and starts it (same mechanism `swaync.service` already uses).

## Validation

`./check.sh`, `./install.sh --dry-run --skip-packages`, and `git diff --check` clean; live cycle verified consistent generated artifacts and `hyprctl configerrors` empty on both modes.

## Exit criteria

Revert by deleting the two theme directories, restoring `config.toml` font keys to `Noto Sans Medium`/`Noto Sans SemiBold`, and re-running `theme.switch.sh`; `git checkout` restores tracked state.

## Follow-up: UI font is Atkinson, code font stays CaskaydiaCove

- Atkinson Hyperlegible Next remains the UI face everywhere (GTK, Qt, Waybar, Rofi, Swaync). A trial of `AtkynsonMono Nerd Font Mono` / proportional Atkinson in Kitty was reverted: the user prefers CaskaydiaCove Nerd Font Mono for terminal and code surfaces. Do not retarget monospace fonts to Atkinson variants.

## Follow-up: Hyprcursor/XCursor size split + gtk3-cursor-fix watcher

- Hyprcursor and XCursor sizes are not 1:1: `HYPRCURSOR_SIZE=46` (compositor) visually matches `XCURSOR_SIZE=32` (GTK/Qt/XWayland). `environment.d/90-cursor-theme.conf` carries the split; `config.toml` `cursor_size` stays 46 because HyDE feeds it to `hyprctl setcursor`.
- HyDE's `theme.switch.sh` rewrites `gtk-cursor-theme-size` in `gtk-3.0/settings.ini` AND `Gtk/CursorThemeSize` in `xsettingsd.conf` with 46 on every theme switch — a single `$CURSOR_SIZE` feeds both, so it cannot be decoupled upstream. `gtk3-cursor-fix.path` (systemd user path unit) watches both files and `gtk3-cursor-fix` restores 32 idempotently, then HUPs xsettingsd. Verified live: 46 -> 32 in ~1s on both files.
- `xsettingsd.service` races Xwayland at graphical-session start ("Unable to open connection to X server", exit 1). Overlay drop-in `xsettingsd.service.d/10-restart.conf` adds Restart=on-failure/3s.

## Follow-up: interactive installer (gum, clack-style)

- `install.sh` now runs a guided UI when `gum` + TTY are present: `◆/◇/●/│/└` chrome in the LAGC Calm palette (sage `A9C080`, amber `D4A55C`, terracotta `D67A6E`), module choose/multiselect, one `sudo -v` + keepalive loop, `gum spin` per step with output to `~/.local/state/my-hyde-dots/install-*.log`, and a `✔` summary.
- gum is bootstrapped via pacman on first interactive run and listed in `packages.arch`. Non-interactive (`--yes`, `--dry-run`, pipe, missing gum/TTY) keeps the old plain output — same behavior, CI-safe (the Omarchy no-TTY bug class is avoided by the `[[ -t 0 ]]` gate).
- Steps were refactored into `step_{packages,cursor,config,themes,apply}` run through `gum spin -- bash -ec`; functions are `export -f`'d and module membership travels as `MODULES_CSV` (arrays cannot be exported). `--only a,b` selects modules non-interactively.
- `packages.arch` audit: dropped `fluent-icon-theme-git` (themes no longer reference Fluent) and `tela-circle-icon-theme-yellow`; added `tela-circle-icon-theme-{green,blue}` (the variants themes actually use, official `extra` repo) and `gum`.

## Follow-up: Inter replaces Atkinson for general UI

- After living with Atkinson Hyperlegible Next as the global UI face, its wide metrics and flat-top terminals (the capital "C" reads clipped) bothered the user. `Inter Medium` now backs `[desktop.ui]`, `document_font`, `[gtk3]`, `[qt5]` and `[qt6]` in `config.toml.in`; Atkinson Next SemiBold remains only on `[waybar]`, where the user prefers its look. `CaskaydiaCove Nerd Font Mono` stays monospace. `inter-font` (official repo) is in `packages.arch`; the Atkinson Next vendor download remains for the bar.
- `install.sh` apply step also sets `org.gnome.desktop.interface font-name` from `config.toml`'s `[desktop.ui]` so GTK4/libadwaita match a fresh install (theme.switch only writes gtk-3.0 `settings.ini`).

## Follow-up: dunst wallbash template shadowed

- HyDE's stock `~/.local/share/wallbash/always/dunst.dcol` runs `scripts/dunst.sh`, which unconditionally ends with `killall dunst; dunst &`. With dunst uninstalled (swaync is the daemon), every login theme apply spawned a GLib "Executable not found: 'dunst'" notification. Wallbash dedupes same-named templates with `~/.config/hyde/wallbash` ahead of `~/.local/share/wallbash` in `WALLBASH_DIRS`, so the overlay shadows both: `always/dunst.dcol` (same template, resolves `WALLBASH_SCRIPTS` to the user dir) and `scripts/dunst.sh` (upstream minus the launch; dunstrc still regenerates, dunst only starts if installed AND swaync absent). Verified: `theme.switch` runs clean, no spawn.
