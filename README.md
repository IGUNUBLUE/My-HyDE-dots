# My HyDE dots

Personal, update-safe overlay for [HyDE](https://github.com/HyDE-Project/HyDE) on Arch Linux.

This repository intentionally stores only user-owned overrides. It does not fork or overwrite HyDE's shared runtime under `~/.local/share/hyde`, `~/.local/share/hypr`, or `~/.local/lib/hyde`.

## Included

- Hyprland monitor layout, Spanish keyboard layouts, gaps, rounding, opacity and faster animations.
- Readable Noto Sans font settings for GTK, Qt, notifications and Waybar.
- Compact transparent Waybar layout and user CSS.
- Dual-screen brightness popup for the laptop panel and LG ULTRAGEAR through DDC/CI.
- Zsh paths for Bun, Volta, PNPM, Linuxbrew and Kiro while leaving HyDE in charge of Starship and Oh My Zsh.
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

The installer uses only official Arch packages, backs up every replaced file and then selects the custom Waybar layout through HyDE's own command.

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
- `~/.config/hyde/config.toml` is HyDE's preserved user configuration.
- Custom Waybar layouts and modules live under `~/.config/waybar/`.
- `~/.config/zsh/user.zsh` is the preserved Zsh customization point.
- Shared files managed by HyDE remain untouched.
