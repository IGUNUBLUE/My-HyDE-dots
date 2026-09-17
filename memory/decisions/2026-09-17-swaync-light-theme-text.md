# Readable swaync text on light themes

- Status: active
- Date: 2026-09-17
- Scope: Swaync, Dunst successors, HyDE Wallbash, LAGC Tech Light
- Sources: live `~/.config/swaync/theme.css`, `~/.local/share/wallbash/theme/swaync.dcol`, `/etc/xdg/swaync/style.css`, HyDE-Project/HyDE master `51b6cbf`

## Context

HyDE generates `~/.config/swaync/theme.css` from `~/.local/share/wallbash/theme/swaync.dcol`, which hardcodes `@define-color text-color #FFFFFF` and paints the notification summary and control center with it. Swaync's stock stylesheet additionally keeps `--text-color: rgb(255,255,255)` for body, time, group headers, DND label and action buttons. Both assumptions hold only for dark surfaces; on `LAGC Tech Light` (or any light wallpaper palette) notification text renders white on a near-white `#F7FCFD` background and appears empty.

## Evidence

- Live `theme.css` resolves `sw-noti-window-bg` to `wallbash_pry1` (`#F7FCFD` on LAGC Tech Light) while `.summary` and `.control-center` use `@text-color` (`#FFFFFF`).
- Baseline `grim` capture of a `notify-send` popup showed both summary and body nearly invisible; after the override the same capture shows dark readable text.
- Upstream template at installed commit `51b6cbf` still hardcodes `#FFFFFF`, so the bug affects every light theme, including official ones such as Catppuccin Latte.
- Collapsed notification groups fall back to the stock `noti-bg-opaque` (`rgb(48,48,48)`) and the mpris widget keeps a dark album-art overlay, so both needed explicit handling.
- Hover states needed a second pass: `.notification-default-action:hover` consumes the unmapped `--noti-bg-hover` var (`rgb(56,56,56)`, dark card under the pointer), the collapsed-group hover is painted cobalt (`sw-noti-gr-collapse-but-hvr`, dark text on `#1B5CFF` ≈ 3.35:1), and the remaining `--noti-bg` triplet consumers (`.inline-reply-button`, `.widget-menubar`) stay dark gray.

## Decision

Keep the fix inside the user-owned `~/.config/swaync/user-style.css` (tracked at `dotfiles/.config/swaync/user-style.css`), which `style.css` imports after `theme.css`. Re-map `text-color`, `text-color-disabled`, `noti-bg-opaque`, `noti-bg-hover-opaque` and the `:root` custom properties `--text-color`, `--text-color-disabled`, `--noti-close-bg`, `--noti-close-bg-hover`, `--noti-bg-focus`, `--noti-bg-hover`, `--noti-bg-darker` onto the active theme's `sw-*`/`wallbash_*` colors, keep mpris overlay text white, and give control-center buttons the theme surface tint. Do not patch the HyDE-managed `theme.css`, `style.css` or `config.json`, and do not shadow the upstream `swaync.dcol` template.

## Validation

`swaync-client -rs` reported success; a live `notify-send` popup and the control center (`swaync-client -op`) showed readable titles, bodies, timestamps, group stacks and the Clear All button under `LAGC Tech Light` in `grim` captures. Palette checks confirm `LAGC Tech Dark` keeps light text on dark surfaces with the same rules.

## Exit criteria

Resolve when upstream `swaync.dcol` derives text color from the palette (for example `wallbash_txt1`) or otherwise renders light themes readably; then re-test a live popup and simplify `user-style.css` to only the owner's visual preferences.
