# My HyDE dots

Personal, update-safe overlay for [HyDE](https://github.com/HyDE-Project/HyDE) on Arch Linux.

This repository intentionally stores only user-owned overrides. It does not fork or overwrite HyDE's shared runtime under `~/.local/share/hyde`, `~/.local/share/hypr`, or `~/.local/lib/hyde`.

Codex and other compatible coding agents should follow [`AGENTS.md`](AGENTS.md) when maintaining or applying this overlay. It defines the upstream boundary, safe change workflow, component-specific rules and required validation.

Durable operational decisions and incident mitigations live in [`memory/index.md`](memory/index.md). This repository memory is portable and reviewable; it deliberately excludes chat history, secrets and generated machine state.

## Included

- Hyprland monitor layout, Spanish keyboard layouts, gaps, rounding, opacity and faster animations.
- Readable Noto Sans font settings for GTK, Qt, notifications and Waybar.
- A reversible `Material Sakura Polished` theme variant with clearer, icon-bearing Qt context menus and moderate spacing, while preserving HyDE's Kvantum/Wallbash pipeline.
- Compact transparent Waybar layout with a stable 22-pixel height across mixed-scale displays and user CSS.
- Kitty user configuration with an 11 pt default font and subtle 0.97 background opacity while retaining HyDE's font family and theme.
- Temporary Hypridle mitigation that keeps 60-second dimming but disables automatic lock, DPMS-off and suspend while the Hyprlock 0.9.6 input issue is unresolved.
- Dual-screen brightness popup for the laptop panel and LG ULTRAGEAR through DDC/CI.
- Clean Zsh startup without an automatic Fastfetch banner, plus paths for Bun, Volta, PNPM global CLIs, Linuxbrew and Kiro while leaving HyDE in charge of Starship and Oh My Zsh.
- Optional wallpaper restoration from Nextcloud.

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

The installer uses only official Arch packages, backs up every replaced file, prepares the user Kvantum template from installed HyDE, and selects the custom Waybar layout through HyDE's own commands.

To use another wallpaper:

```bash
MY_HYDE_WALLPAPER=/absolute/path/image.png ./install.sh
```

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
- Qt menu changes live in a derived theme under `~/.config/hyde/themes/Material Sakura Polished`; the original `Material Sakura` theme and HyDE's generated `~/.config/Kvantum/wallbash` files remain untouched.
- Shared files managed by HyDE remain untouched.

## Qt menu preferences

Run `./install.sh --qt-menu-only --skip-packages` to apply only the menu settings. New Qt windows use the current theme with your persistent menu preferences. GTK and browser-owned menus are outside this customization. Shadow shape remains defined by the active theme SVG. The old Material Sakura Polished copy may remain locally for rollback but is no longer needed.

The template and callback are recorded in the normal backup manifest. After `./restore.sh`, reselect your current theme to regenerate Kvantum with the restored template. No wallpaper or generated Kvantum configuration is stored in Git.

Reference: [HyDE Wallbash templates and post-processing](https://github.com/HyDE-Project/HyDE/blob/master/Configs/.config/hyde/wallbash/README.md).
