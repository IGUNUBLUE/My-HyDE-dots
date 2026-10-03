# rhun editor LAGC themes that follow the active HyDE theme

- Date: 2026-10-03
- Status: active
- Sources: user request (LAGC versions for https://github.com/vshvedov/rhun, following `Super+Shift+T`); rhun source at commit `72c60808a9625a418c26a9f4b5d44042bc88d0cc` (`src/app/theme.s`, `src/app/config.s`, `src/app/watch.s`, `src/app/app.s`, `docs/guide.md`); installed rhun 0.16.6; HyDE `~/.local/lib/hyde/color.set.sh`; palette from the tracked VSCodium `lagc-themes` JSONs.

## Context

The user wanted the four LAGC themes (Calm/Tech, Dark/Light) in the rhun editor and wanted rhun to change with the HyDE theme selector, like the agent-CLI themes do. rhun loads user themes from `~/.config/rhun/themes/*.theme` and its active theme from `[ui] theme` in `~/.config/rhun/config`.

## Evidence

- A first draft followed DeepWiki and used `lineno`, `lineno_active` and `line_hl`. rhun's slot table (`slot_names`, `.Ls0`-`.Lg2` in `src/app/theme.s`) names them `line_number`, `line_number_active` and `line_highlight`; unknown keys are ignored silently and the slot is derived from `bg`/`fg`/`accent`. The validator now carries the exact 66-key table (verified identical, same order, against the source) and rejects any key rhun would ignore.
- `theme_load` matches every key against that one flat table and never reads the INI section, so `[terminal]`/`[syntax]` are cosmetic; the placement of `git_*` does not matter.
- `theme_scan` sets a user theme's `TH_id` with `stem_dup` (file name without `.theme`); `theme_find(cfg_theme)` matches on that id. If the configured id is missing, `app_init` falls back to `rhun-dark`.
- `watch_init` watches the config directory; `on_inotify` calls `app_reload_config` on `IN_CLOSE_WRITE`/`IN_MOVED_TO` of the file named `config` when its mtime changed, and `app_apply_settings` calls `theme_apply` only when the theme index changes. A same-directory temp file plus `mv` therefore triggers exactly one reload.
- `color.set.sh` replaces `<wallbash_mode>` with `dcol_mode` (or the inverse when colors are reverted), skips a template whose target directory is missing, exports `HYDE_THEME`/`HYDE_THEME_DIR` and runs the header command in the background after writing the target. Every LAGC `theme.dcol` sets `dcol_mode`.

## Decision

- Theme sources: `dotfiles/.config/rhun/themes/lagc-{calm,tech}-{dark,light}.theme`, every one of rhun's 66 slots set explicitly, palette 1:1 from the VSCodium themes.
- Follow hook: `wallbash/always/rhun-theme.dcol` writes the mode to `${XDG_CONFIG_HOME:-$HOME/.config}/rhun/.wallbash-mode` and runs `wallbash/scripts/my-hyde-rhun-theme.sh`. The script takes `HYDE_THEME` (else `HYDE_THEME_DIR` basename, else `staterc`), maps the four LAGC names 1:1 and any other theme to `lagc-calm-$mode`, refuses a theme that is not installed, rewrites only `[ui] theme` atomically, creates a minimal config when none exists, and does nothing when the value is already correct.
- `install_rhun_theme` (called by `step_themes` and `--rhun-theme-only`) validates, installs the themes, template and script with backups, then renders the hook once through `color.set.sh --single`. `restore.sh --rhun-theme-only` removes those overlay-owned files and the marker; rhun's `config` is left alone.
- A theme picked by hand inside rhun lasts until the next HyDE theme switch. rhun is not an Arch package; `packages.arch` is unchanged.

## Follow-up: fonts follow HyDE

- The user found rhun's built-in Iosevka hard to read. rhun's `[ui] font` and `[editor] font` take a path to a `.ttf`; `src/gfx/font.s` parses only TrueType `glyf` outlines and only the first face of a `ttcf` collection; `load_font_or` falls back to the built-in font when the file is missing or unreadable.
- The follow hook now also writes those two keys from the HyDE fonts: `$FONT`/`$MONOSPACE_FONT` from the active theme's `hypr.theme` (the same variables `theme.switch.sh` reads), else `[desktop.ui] font`/`monospace_font` in `config.toml` — currently `Inter Medium` and `CaskaydiaCove Nerd Font Mono`. Each family goes through `fc-match`; a fallback to another family, a non-TrueType format or a face without `glyf`/`loca`/`cmap` leaves rhun's value untouched. `Inter Medium` is face 10 of `Inter.ttc`, so that face is copied into a standalone `~/.config/rhun/fonts/ui.ttf` (regenerated on each switch, removed by `restore.sh --rhun-theme-only`).
- Headless comparison (`rhun --headless --script` with `shot`) showed CaskaydiaCove clearly wider and more legible than Iosevka in the editor, and Inter Medium matching the GTK/Qt UI. A `--control` session proved that editing the font keys in the config does not reload fonts in a running rhun (`app_reload_config` → `app_apply_settings` never calls `app_load_fonts`; only the Settings page does), while the theme key does. Fonts therefore apply on rhun's next start; colors remain live.
- Font sizes stay rhun's own (`[ui] font_size`, `[editor] font_size`); HyDE's point sizes are not mapped because rhun's are pixel-scaled.

## Validation

- `tools/validate-rhun-themes.py --check`, `./check.sh`, `./install.sh --dry-run --skip-packages`, `./install.sh --rhun-theme-only --dry-run`, `bash -n` on the lifecycle scripts and `git diff --check` pass.
- The follow script was tested in a temporary `XDG_CONFIG_HOME` holding a copy of the real rhun 0.16.6 config: LAGC exact match, non-LAGC Calm fallback, `staterc` fallback, missing-theme refusal, every other config line preserved byte for byte.
- Observed live on 2026-10-03 with rhun 0.16.6 running (same pid throughout, no restart): `./install.sh --rhun-theme-only` moved `[ui] theme` from `gruvbox-dark` to `lagc-tech-light` and rhun rendered `#EFF6F7`/`#E3EEF1`/`#B2CBD3`/`#12717C`; `hydectl theme set "LAGC Calm Dark"` switched rhun within one 0.5 s poll to `#2B2522`/`#352E29`/`#4A423B` (settings page showed "LAGC Calm Dark"); the non-LAGC `Catppuccin Latte` produced mode `light` and `lagc-calm-light` (`#F4EEE2`/`#EAE3D5`/`#C9BCA6`); switching back to `LAGC Tech Light` restored `lagc-tech-light`. `hyprctl configerrors` empty and Waybar running afterwards. Colors were sampled from `grim` captures of the rhun window.

## Exit criteria

- Revisit if rhun renames slots in `src/app/theme.s`, moves `[ui] theme`/`font` or `[editor] font`, changes the file-stem id rule, learns CFF/variable fonts or live font reload from the config file; if the user wants rhun's "Follow Omarchy" mode instead; or if the non-LAGC fallback should use the Tech family.
