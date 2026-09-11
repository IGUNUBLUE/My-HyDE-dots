# AGENTS.md

## Purpose

This repository is the installable, update-safe source of truth for the owner's HyDE customizations. Improve the personal overlay without forking HyDE, replacing upstream-managed runtime files, or capturing private user state.

## Sources of truth

- Treat files under `dotfiles/` as the desired portable state.
- Read `memory/index.md` and every relevant active memory before changing a component. Memories provide historical evidence and safeguards but do not replace current live or upstream verification.
- Treat `install.sh`, `restore.sh`, `update-snapshot.sh`, and `check.sh` as the supported lifecycle.
- Treat the active files under `$HOME/.config/` and `$HOME/.local/bin/` as runtime state, not as the only copy of a change.
- Before relying on a HyDE option or command, check the current official documentation and the `HyDE-Project/HyDE` repository. Verify consequential behavior against the repository files, not only search summaries.
- Prefer HyDE's documented user override points and commands. Do not invent config keys, module syntax, or reload commands.

## Upstream boundary

- Never commit or overwrite HyDE-managed files under `~/.local/share/hyde`, `~/.local/share/hypr`, `~/.local/share/waybar`, or `~/.local/lib/hyde`.
- Keep personal Hyprland settings in `~/.config/hypr/hyprland.lua` and its snapshot.
- Keep personal HyDE settings in `~/.config/hyde/config.toml` and `config.toml.in`; retain the upstream schema declaration.
- Keep Waybar changes in the custom `my-hyde.jsonc` layout, user modules, and `user-style.css`.
- Keep shell additions in `~/.config/zsh/user.zsh`. Do not replace HyDE's shell bootstrap or plugin manager.
- Add a package only when the overlay directly requires it and it is available from an appropriate Arch source. Prefer official repository packages over AUR replacements.

## Safety and privacy

- Preserve documents, media, Nextcloud content, browser profiles, credentials, keyrings, shell history, caches, and unrelated dotfiles.
- Never commit tokens, passwords, private keys, machine identifiers that are not required, generated caches, or HyDE runtime state.
- Parameterize home paths with `@HOME@` in tracked templates. Do not commit `/home/l` when the value should be portable.
- Hardware-specific monitor names and DDC/CI identifiers are allowed only where required and must be documented in `README.md`.
- Before package removal or a destructive cleanup, inspect HyDE's current core package list and simulate the package transaction. Do not remove a dependency merely because it originated with KDE.
- Existing target files must be backed up before installation. A restore operation must affect only paths recorded by this overlay.

## Change workflow

1. Inspect the current tracked configuration and the relevant official HyDE documentation or source.
2. Make the smallest compatible change in `dotfiles/` and any required lifecycle script.
3. If the request is for a live desktop change, back up the affected live file, apply the tracked version through `install.sh` or the documented HyDE command, and reload only the affected component.
4. If the user changed the live desktop manually, run `./update-snapshot.sh` and review the diff before accepting it.
5. Keep `README.md`, `packages.arch`, install behavior, and rollback behavior synchronized with material changes.
6. Add or update a repository memory when an incident, compatibility constraint, rollback condition, or non-obvious decision must survive future sessions.
7. Do not commit or push unless the user asks for publication or the current task explicitly includes maintaining this repository.

## Component rules

### Hyprland and displays

- Preserve the bootstrap block at the start of `hyprland.lua`; removing it can produce an empty Hyprland session.
- Use HyDE's Lua APIs already established in the file instead of adding a parallel `hyprland.conf`.
- Keep both Spanish layouts (`es,latam`) unless explicitly changed.
- Treat output names, positions, refresh rates, and scales as hardware-specific. Inspect `hyprctl monitors all` before changing them.
- After a change, require an empty `hyprctl configerrors` result.
- Preserve the temporary Hypridle mitigation: dimming remains enabled, while automatic lock, DPMS-off and suspend stay disabled until Hyprlock passes a controlled dual-monitor lock/unlock test.

### Waybar

- Preserve the `my-hyde` custom layout name and select it with `hyde-shell waybar --set`.
- Keep the layout at the historical 22 logical pixels together with the scoped `#pill` `min-height: 0` override; test every active output manually after changing either. The earlier 25-pixel workaround passed reload/theme-cycle checks but still resized during real pointer crossing, while 26 pixels remains the known-safe rollback.
- Prefer `user-style.css` for visual adjustments and the custom module file for brightness behavior; do not edit generated `config.jsonc` or upstream styles.
- Maintain usable click targets and readable text when reducing height, padding, icon size, or gaps.
- After a change, verify that Waybar is running, the active layout in `~/.local/state/hyde/staterc` is `my-hyde`, and the generated config contains every custom module.

### Brightness popup

- Preserve independent support for the internal panel through `brightnessctl` and the external LG monitor through `ddcutil`.
- A missing external DDC display must degrade gracefully rather than preventing Waybar from starting.
- Validate the Python script, its JSON status output, executable mode, and right-click popup behavior after changes.

### Fonts, themes, and wallpaper

- Keep font changes consistent across HyDE, GTK, Qt, notifications, and Waybar where applicable.
- Keep application windows fully opaque (`active_opacity` and `inactive_opacity` = 1). The current solid-first profile disables compositor blur and inner glow because diffuse blur causes eye strain; retain only small alpha transparency on Waybar islands, Rofi, Dunst and Kitty. The user-owned layer override intentionally disables blur for `rofi`, `notifications`, `waybar` and `logout_dialog`. Do not add a `class = ".*"` rule with `opaque = true`; opacity 1 in the compositor config is enough and keeps future surface-level transparency possible.
- Verify any decoration snippet against the installed release with `hyprctl getoption` before using it; the Hyprland wiki documents `latest git`. With the Lua parser, apply live experiments with `hyprctl eval 'hl.config({...})'` and revert with `hyde-shell -r`; `hyprctl keyword` no longer works.
- Use HyDE's wallpaper command; do not commit the wallpaper image or other Nextcloud content.
- Wallpaper absence must be non-fatal on a fresh machine.

### Cursor

- Keep the global cursor in HyDE's documented `[desktop.ui]` `cursor_theme` and `cursor_size` keys, not in shared HyDE runtime files.
- Preserve the pinned GPLv3 Future-cyan XCursor payload and native Hyprcursor source, including their licenses, provenance, aliases, and reviewed hotspot data.
- Keep `~/.config/environment.d/90-cursor-theme.conf`, both user-owned `default/index.theme` aliases, and the HyDE setting synchronized on the single `Future-cursors` identifier so native Hyprcursor, GTK, legacy and XWayland clients do not select different themes.
- Use the visually accepted logical size 42 while the active outputs remain scale 1.0 and 1.25; size 36 was too small and size 48 appeared oversized and blurred on the external display.
- After cursor changes, test the default arrow, link pointer, text beam, resize cursors, clicks on small targets, and pointer crossing on every output. Do not claim hotspot alignment from static inspection alone.

### Zsh

- Preserve HyDE's Starship and Oh My Zsh ownership while retaining the user's PATH integrations for OMP, Bun, Volta, PNPM, Linuxbrew, and other documented tools.
- Do not commit `.zsh_history` or machine-local secrets.
- Validate shell changes in a fresh interactive Zsh process, not only the current inherited environment.

### Kitty

- Track only `~/.config/kitty/kitty.conf`, which HyDE preserves as the user override.
- Do not track or replace HyDE-managed `hyde.conf` or theme-managed `theme.conf`.
- Keep personal overrides after `include hyde.conf` so their precedence is explicit and update-safe.

## Required validation

Run these before committing:

```bash
./check.sh
./install.sh --dry-run --skip-packages
git diff --check
git diff
```

For a live desktop change, also verify:

```bash
hyprctl configerrors
pgrep -x waybar
~/.local/bin/hyde-brightness-panel --status | python -m json.tool
zsh -lic 'command -v omp; print -r -- "ZDOTDIR=${ZDOTDIR:-unset}"'
```

Do not describe a change as verified when only static validation ran. Report separately whether it was reviewed, installed, reloaded, and observed live.

## Code Review Rules

- Flag any change that writes into HyDE's shared runtime instead of a user override.
- Flag absolute home paths that should use `@HOME@`.
- Flag generated files, histories, credentials, caches, wallpaper binaries, or unrelated desktop configuration entering the repository.
- Flag visual changes that modify only the live desktop but are missing from `dotfiles/`, or tracked changes that are never installed.
- Flag new dependencies missing from `packages.arch`, and packages listed there without a demonstrated runtime need.
- Flag rollback changes that can delete or restore paths outside the overlay manifest.
- Flag monitor or DDC changes that silently assume identical hardware on every installation; require documentation or graceful detection.
- Flag changes that contradict an active repository memory without resolving its exit criteria and updating the memory index.
