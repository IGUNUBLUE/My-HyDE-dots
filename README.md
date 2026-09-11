# My HyDE dots

Personal, update-safe overlay for [HyDE](https://github.com/HyDE-Project/HyDE) on Arch Linux.

This repository intentionally stores only user-owned overrides. It does not fork or overwrite HyDE's shared runtime under `~/.local/share/hyde`, `~/.local/share/hypr`, or `~/.local/lib/hyde`.

Codex and other compatible coding agents should follow [`AGENTS.md`](AGENTS.md) when maintaining or applying this overlay. It defines the upstream boundary, safe change workflow, component-specific rules and required validation.

Durable operational decisions and incident mitigations live in [`memory/index.md`](memory/index.md). This repository memory is portable and reviewable; it deliberately excludes chat history, secrets and generated machine state.

## Included

- Hyprland monitor layout, Spanish keyboard layouts, and a solid-first visual layer: opaque windows, 12 px squircle corners, palette-driven shadows, a looping border gradient, and only small alpha transparency on selected surfaces.
- Readable Noto Sans font settings for GTK, Qt, notifications and Waybar.
- A reversible `Material Sakura Polished` theme variant with clearer, icon-bearing Qt context menus and moderate spacing, while preserving HyDE's Kvantum/Wallbash pipeline.
- Native `LAGC Tech Dark` and `LAGC Tech Light` themes derived from the lagc-tech midnight/frost/cobalt/cyan/ember palette. They use HyDE's supported theme-switch, Wallbash, Waybar, Kitty and Rofi contracts, and drive Dunst plus Kvantum through the standard Wallbash templates.
- A portable Kiro IDE extension with selectable `LAGC Tech Dark` and `LAGC Tech Light` color themes, installed only through Kiro's own VSIX CLI.
- A documented Zed local theme family with selectable `LAGC Tech Dark` and `LAGC Tech Light` appearances, merged safely into the user-owned Zed settings file.
- Compact transparent Waybar layout with a historical 22-pixel height, scoped GTK minimum-size overrides, and mandatory mixed-scale display validation.
- Pinned GPLv3 `Future-cyan` cursor theme at visually accepted logical size 42, with native Hyprcursor plus XCursor fallback, reviewed hotspot corrections, and consistent HyDE/session/GTK defaults.
- Kitty user configuration with an 11 pt default font and 0.90 background opacity for slight transparency without compositor blur.
- Semi-transparent Rofi launcher (90 % wallpaper-matched background) and a Wallbash-generated `hyde-wallbash` theme for btop, both driven by the tracked templates under `~/.config/hyde/wallbash/`.
- Temporary Hypridle mitigation that keeps 60-second dimming but disables automatic lock, DPMS-off and suspend while the Hyprlock 0.9.6 input issue is unresolved.
- Dual-screen brightness popup for the laptop panel and LG ULTRAGEAR through DDC/CI.
- Clean Zsh startup without an automatic Fastfetch banner, plus paths for Bun, Volta, PNPM global CLIs, Linuxbrew and Kiro while leaving HyDE in charge of Starship and Oh My Zsh.
- Optional wallpaper restoration from Nextcloud.

## Visual layer

The visual profile is intentionally solid-first because diffuse blur causes eye strain. Windows remain fully opaque, shadows and borders preserve depth, and selected surfaces keep only small alpha transparency.

- `dotfiles/.config/hypr/hyprland.lua` disables compositor blur and inner glow, keeps `decoration.shadow` plus the LAGC border gradient, and uses `rounding = 12` with `rounding_power = 2.4` (squircle).
- Waybar islands use `alpha(@main-bg, 0.99)`, Rofi uses alpha `F7`, Dunst stays theme-controlled, and Kitty uses 0.97. These values leave only a minimal amount of transparency without a diffuse backdrop.
- HyDE's shared layer rules enable blur by default, so the user override explicitly disables it for `rofi`, `notifications`, `waybar` and `logout_dialog`. The Waybar layer keeps its 22 px geometry and the same mixed-scale validation requirement.
- HyDE owns the animation timings. Choose a preset with `SUPER + SHIFT + Y` and scale every preset from `config.toml` with `[hyprland.anim] duration_scale = 0.9` (`0.9` is 10 % faster).

Companion selectors ship with HyDE and are deliberately not tracked here, because they are per-machine state:

```bash
hyde-shell animations --select   # SUPER + SHIFT + Y
hyde-shell hyprlock --select     # SUPER + SHIFT + U
hyde-shell shaders --select      # screen shader: vibrance, wallbash, custom
hyde-shell theme.import --select # gallery themes with GTK, icon and font assets
```

Notes for later changes:

- The Hyprland wiki documents the `latest git` branch. This machine runs 0.56.2, which has no `decoration.blur.variant` (the `acrylic`, `frost`, `aurora`, `water` liquid-glass variants) and no `decoration.wobble`. Verify any option with `hyprctl getoption` before trusting a snippet.
- With the Lua parser `hyprctl keyword` no longer works (`keyword can't work with non-legacy parsers. Use eval`). Preview a change with `hyprctl eval 'hl.config({...})'` and revert with `hyde-shell -r`.

## Fresh installation

1. Install or update official HyDE first.
2. Restore the Nextcloud wallpaper folder if desired.
3. Clone and apply this overlay:

```bash
git clone git@github.com:IGUNUBLUE/My-HyDE-dots.git
cd My-HyDE-dots
./install.sh --dry-run
./install.sh
```

The installer uses only official Arch packages, backs up every replaced file or symlink-rich managed tree, installs the pinned user-owned cursor payload, prepares the user Kvantum template from installed HyDE, and selects the custom Waybar layout through HyDE's own commands.

To use another wallpaper:

```bash
MY_HYDE_WALLPAPER=/absolute/path/image.png ./install.sh
```

## LAGC Tech themes

The overlay installs two native HyDE themes without committing any wallpaper content. When an existing wallpaper is available, `install.sh` creates a reversible `wall.set` link for each theme; alternatively, provide one through `MY_HYDE_WALLPAPER` during installation. Switch themes through HyDE's native command:

```bash
hyde-shell theme.switch -s "LAGC Tech Dark"
hyde-shell theme.switch -s "LAGC Tech Light"
```

The themes use existing `Catppuccin-Mocha` and `Catppuccin-Latte` GTK assets for their GTK base. HyDE's standard Wallbash pipeline applies the LAGC palette to Dunst and Kvantum; no shared HyDE runtime files are overwritten. A user-owned Wallbash post-render callback makes the Light theme's Rofi window-switcher selection Signal Cyan (`#17D7E8`) with Midnight text (`#061B2B`) after the shared opaque-Rofi template runs, without changing Kvantum's Cobalt highlight and link roles.

## Future-cyan cursor

The default cursor is the GPLv3 [Future-cyan](https://www.gnome-look.org/p/1465392) theme from [Future-cursors](https://github.com/yeyushengfan258/Future-cursors), pinned to commit `587c14d2f5bd2dc34095a4efbb1a729eb72a1d36`. That upstream revision explicitly improves hotspot consistency. The reviewed compiled XCursor payload, license and provenance are tracked under `dotfiles/.local/share/icons/Future-cursors/`; installation does not download or execute third-party code.

For native compositor support, the overlay also pins the GPLv3 [Future Cyan Hyprcursor port](https://gitlab.com/Pummelfisch/future-cyan-hyprcursor) at `cf4126d17f4520aceb688d8a60daca4a1f0b9e80`. Its reviewed SVG working source lives under `cursor-sources/Future-cyan-hyprcursor/` and is compiled locally with `hyprcursor-util` during installation. The overlay uses one `Future-cursors` identifier for both formats and adjusts the native arrow and link-pointer hotspots to the corrected original ratios.

HyDE and native Hyprcursor, the login environment, GSettings, XCursor and both user default aliases select `Future-cursors` at the visually accepted logical size 42. On the mixed-scale outputs, 36 was too small while 48 appeared oversized and blurred on the scale-1.0 external monitor. Existing applications can retain their inherited cursor environment, so log out and back in after the first installation before judging every GTK/XWayland client. Hotspot acceptance still requires clicking small targets and checking arrow, link, text and resize shapes on both monitors.

Reference: [HyDE main configuration](https://hydeproject.pages.dev/en/configuring/config_toml/) and [HyDE cursor guidance](https://github.com/HyDE-Project/HyDE/discussions/624).

## Kiro IDE themes

The overlay also includes a VS Code-compatible extension containing selectable `LAGC Tech Dark` and `LAGC Tech Light` themes. It does not copy files into Kiro's private extension directory. Instead, the installer builds a temporary VSIX from `dotfiles/.local/share/kiro/themes/lagc-tech/` and passes it to Kiro's supported CLI:

```bash
./install.sh --kiro-theme-only
```

The normal `./install.sh` flow installs or updates the same extension whenever the `kiro` CLI is available. In Kiro, use **Preferences: Color Theme** (`Ctrl+K`, then `Ctrl+T`) and select `LAGC Tech Dark` or `LAGC Tech Light`. To remove only this overlay-owned extension:

```bash
./restore.sh --kiro-theme-only
```

## Zed editor themes

Zed loads local theme families from `~/.config/zed/themes/` on Linux. The overlay installs `lagc-tech.json` there and merges only its `theme.light` and `theme.dark` selections into the existing `~/.config/zed/settings.json`; unrelated editor, agent, language, and credential settings remain untouched. Your current Zed theme mode is preserved, or defaults to the documented `system` mode for a new settings file.

```bash
./install.sh --zed-theme-only
```

Use Zed’s Theme Selector (`Ctrl+K`, then `Ctrl+T`) to preview either appearance. The theme source is tracked at `dotfiles/.config/zed/themes/lagc-tech.json`; `update-snapshot.sh` captures only that theme file and never copies the full settings file, preventing private Zed configuration from entering this repository.

Reference: [Zed themes](https://zed.dev/docs/themes) and [Zed theme extensions](https://zed.dev/docs/extensions/themes).

## Restore the previous configuration

```bash
./restore.sh
```

Pass a specific directory under `~/.local/state/my-hyde-dots/backups/` to restore an older snapshot.

## Capture later changes

```bash
./update-snapshot.sh
./check.sh
git diff
git add .
git commit -m "Update HyDE preferences"
git push
```

Always review the diff before committing. Histories, caches, credentials, KWallet, browser profiles and generated HyDE state are deliberately excluded.

## Repository memory

Before changing a component, read `memory/index.md` and its relevant active entries. Create new memories from `memory/template.md`; resolve rather than delete old decisions so future installations retain the reason behind important safeguards.

## Hardware assumptions

The current Hyprland override targets:

- Laptop display: `eDP-1`, scale `1.25`.
- External display: `LG ULTRAGEAR`, scale `1`, positioned at `1536x0`.
- DDC/CI model name: `LG ULTRAGEAR`.

Edit the two hardware-specific files before installing on a different machine:

- `dotfiles/.config/hypr/hyprland.lua`
- `dotfiles/.local/bin/hyde-brightness-panel`

## Upstream conventions followed

- `~/.config/hypr/hyprland.lua` is HyDE's preserved Lua override.
- `~/.config/hypr/hypridle.conf` is HyDE's preserved idle override; automatic locking must be restored only after a controlled lock/unlock test succeeds.
- `~/.config/hyde/config.toml` is HyDE's preserved user configuration.
- Custom Waybar layouts and modules live under `~/.config/waybar/`.
- `~/.config/kitty/kitty.conf` is the preserved Kitty override; HyDE remains responsible for `hyde.conf` and `theme.conf`.
- `~/.config/zsh/user.zsh` is the preserved Zsh customization point.
- `~/.config/hyde/wallbash/` is HyDE's documented user template directory and takes precedence over the shared templates that ship with HyDE. Only the overlay's own templates are tracked: `always/rofi-frosted.dcol`, `always/btop.dcol` and `scripts/my-hyde-btop.sh`.
- Qt menu changes live in a derived theme under `~/.config/hyde/themes/Material Sakura Polished`; the original `Material Sakura` theme and HyDE's generated `~/.config/Kvantum/wallbash` files remain untouched.
- Shared files managed by HyDE remain untouched.

## Qt menu preferences

Run `./install.sh --qt-menu-only --skip-packages` to apply only the menu settings. New Qt windows use the current theme with your persistent menu preferences. GTK and browser-owned menus are outside this customization. Shadow shape remains defined by the active theme SVG. The old Material Sakura Polished copy may remain locally for rollback but is no longer needed.

The template and callback are recorded in the normal backup manifest. After `./restore.sh`, reselect your current theme to regenerate Kvantum with the restored template. No wallpaper or generated Kvantum configuration is stored in Git.

Reference: [HyDE Wallbash templates and post-processing](https://github.com/HyDE-Project/HyDE/blob/master/Configs/.config/hyde/wallbash/README.md).
