# nmrs replaces the nm-applet network GUI

- Status: superseded
- Replaced by: [networkmanager-dmenu](2026-10-22-networkmanager-dmenu.md)
- Date: 2026-10-21
- Scope: NetworkManager, nmrs, nm-applet, Waybar, AUR, install and rollback
- Sources: owner request to prefer the recommended GUI and make installation replace the old one; official HyDE `fa2fd57afc7203b1b5653d3271f3a57ea3873f97` startup, variables and core dependencies; upstream nmrs-gui `nmrs-gui-v1.6.0` and AUR `nmrs` PKGBUILD; XDG Autostart Specification.

## Context

The nm-applet tray menu extended past the screen and the owner could not
scroll to a visible Wi-Fi network. The overflow cause remains unconfirmed.
The owner requested nmrs-gui as the default installed network interface and
removal of the old GUI.

## Evidence

- HyDE's current core package list includes both `networkmanager` and
  `network-manager-applet`. Only the latter is explicitly replaced here.
- Lua `variables.lua` defines `hyde.config.start.applet_network_manager`;
  `start_up.lua` skips empty strings. The callback reads the same startup
  table after the user's Lua overrides load.
- This session also launched nm-applet through the XDG-generated
  `app-nm\x2dapplet@autostart.service`. Blanking only the Lua setting does
  not disable that launch. A same-named user desktop entry with `Hidden=true`
  overrides `/etc/xdg/autostart/nm-applet.desktop` by specification.
- Upstream 1.6.0 has a vertically scrolling network list. The AUR `nmrs`
  PKGBUILD compiles the tagged release and installs its binary as `nmrs`,
  not `nmrs-gui`. Cargo keeps the upstream name. The release has no uploaded
  binary assets, AUR has no nmrs-bin variant, and Arch's official package
  search has no nmrs package as of this review.
- Current Wi-Fi secret flags are zero (NetworkManager-owned); only flag
  counts were inspected, never credentials. The frontend passes passwords
  directly when connecting. Agent-owned Wi-Fi/VPN secrets on other machines
  need separate verification; this does not authorize rewriting profiles.

## Decision

- Declare `networkmanager` in `packages.arch` and the sole required AUR
  exception `nmrs` in `packages.aur`. Use an existing yay/paru as the normal
  user; do not silently bootstrap an AUR helper or add an external repository.
- Keep the startup override in `hyprland.lua`, the Hidden desktop entry in
  `dotfiles/.config/autostart/`, and `network#nmrs` in a user Waybar module.
  Its status/icon/interval retain upstream network behavior and 24-pixel bar
  geometry. Left/right click invokes the user launcher, which focuses an
  existing nmrs window or launches the available executable.
- Full installs and `--network-only` install/validate the replacement before
  deploying these settings. After configuration succeeds, simulate and
  remove only `network-manager-applet` with nonrecursive `pacman -R`.
  Refuse a different removal plan. Preserve NetworkManager, profiles,
  keyrings, nm-connection-editor and shared libraries.
- `--skip-packages` skips installation and removal and requires a working GUI
  before replacing the current settings. Dry runs make no package changes.
- Do not patch shared HyDE runtime or the system desktop entry. Reapply the
  overlay if upstream reinstalls its core applet; the user launch overrides
  remain effective even while the package is installed.
- The GNOME cleanup memory's prohibition on automatically uninstalling GNOME
  still applies. This narrow owner-authorized applet replacement is the only
  exception added here.

## Validation

- AUR source and desktop-entry checksums verified; the reviewed 1.6.0 package
  built successfully and its binary returned a version.
- Five sandbox tests cover exact nonrecursive removal, rejection of a wider
  plan, rejection of a broken replacement, AUR failure preserving existing
  settings, and focused install/restore with no package operations. Rollback
  preserves an unrelated sentinel and never restores package metadata into
  HOME.
- Live installation and desktop observations are recorded after application;
  static validation alone does not establish click/scroll acceptance.

## Rollback

Reinstall `network-manager-applet` with `sudo pacman -S --needed`, restore the
focused backup through `restore.sh`, then log in again. The backup manifest
covers only the changed user files, including the CSS, hooks and desktop icon. `.network-package-state` records the old
package version privately and is excluded from file restoration. Package
rollback is explicit; restore does not remove nmrs or other packages.

## Exit criteria

Revisit if upstream changes its startup key or core package contract, an
official Arch/binary package becomes available, nmrs changes its executable
or window class, or saved Wi-Fi/VPN secrets need a persistent secret agent.
Do not disable NetworkManager or migrate private network profiles to resolve
GUI integration issues.

## Follow-up: LAGC styles, launcher identity and Rofi rollback

- Four CSS palettes use the existing LAGC Calm/Tech dark/light source colors.
  The common layout is adapted from the tagged nmrs MIT CSS with its license
  and provenance retained. The GTK4 parser validates every composition, and
  the palette generator checks text, selection and state contrast.
- The user `nmrs.dcol` hook selects the exact active LAGC palette, with a Calm
  fallback by mode for other themes. The launcher resynchronizes on opening.
  nmrs 1.6 has no external CSS file watcher, so existing windows need reopening;
  never restart an active password or network dialog on theme changes.
- The `.desktop` override declares `StartupWMClass=org.nmrs.ui` and points to
  the user launcher. An original user SVG under hicolor supplies its missing
  launcher/window icon. No system desktop entry is overwritten.
- nmrs itself sets the main window's title to an empty string. A custom Rofi
  script mode successfully supplied a fallback label but changed the launcher's
  presentation; the owner rejected it. All custom Rofi styles, script and
  TOML keys were removed and the original launcher was restored. Do not revive
  this workaround. The native window selector's blank nmrs label is retained
  as an upstream limitation; the normal app launcher has its desktop name.
- Restoring `config.toml` initially left the old launcher keys in HyDE's derived
  state, pointing to the removed style. The documented `hyde-shell config
  --no-daemon` regenerated the exports and the owner confirmed the menu works.
  Normal config application and recorded-TOML restoration now invoke that
  command before reloading. Never patch generated/shared HyDE configuration.
- Explicit Tela mode variants fix pale tray glyphs on light bars. The network
  icon stays persistent on click; bandwidth moved to the tooltip instead of
  displaying mint/amber inline colors. Font sizes and 24-pixel geometry stay.
- The 2026-10-21 full browser/theme run was interrupted during launcher recovery;
  do not report it as a completed pass. Revalidate the final state separately.

## Final validation (2026-10-22)

- `./check.sh`, `./install.sh --dry-run --skip-packages` and whitespace checks
  passed after the Rofi rollback. Six sandbox cases cover package failure and
  removal boundaries, focused file restoration, four-theme following,
  idempotence and preservation of unrelated preferences.
- The final `BROWSERS='' REPAINT=3 tests/live-theme.sh` run passed 135 checks
  with zero failures across the four LAGC themes, then restored LAGC Tech Light.
  It exercised GTK3/GTK4/libadwaita state, theme artifacts, icons, nmrs CSS
  selection and visible Waybar bars on the internal and external displays.
  Browser windows were excluded from this final run.
- nmrs 1.6.0-1 is installed; network-manager-applet is absent; NetworkManager
  remains installed. The launcher desktop entry and SVG validate. The accepted
  native launcher is restored and no custom Rofi selector/style references
  remain in the user's source or generated configuration.
- Hyprland has no configuration errors. The Waybar service and wallpaper are
  active. This change does not claim a new mixed-scale pointer-crossing,
  brightness-popup or Wi-Fi connection acceptance test.
