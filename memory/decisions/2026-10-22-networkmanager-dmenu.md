# NetworkManager menu through Rofi

- Status: active
- Date: 2026-10-22
- Scope: NetworkManager, Rofi, Waybar, install/restore/snapshot
- Sources: explicit owner request to replace nmrs; upstream networkmanager-dmenu 2.7.2, official Arch extra package, HyDE current pkg_core.lst and variables.lua, HyDE Making Themes documentation, installed Rofi 2.0 parser.

## Context

nmrs 1.6 publishes an empty main window title. The owner accepted the proposed
NetworkManager Rofi menu to avoid that identity issue and maintain Waybar access.

## Evidence

Official Arch extra provides networkmanager-dmenu 2.7.2-1. Its installed source
sorts access points by get_strength() descending and supports masked Rofi input.
The current HyDE startup key, core package exception and Rofi color template
contract were verified against official source and theme documentation.

## Decision

Use the official `networkmanager-dmenu` package and existing NetworkManager.
Its `get_access_points()` sorts strength descending; `-no-sort` preserves that
order during Rofi filtering. `obscure=True` masks password entry. No network
profile, keyring or saved credential is copied, rewritten or committed.

`custom/network-status` keeps the persistent Waybar icon and 24-pixel geometry. Its
wrapper locks only its own invocation and opens a standalone user network.rasi
with `-no-config`. It imports the existing generated `theme.rasi` colors, so
all four LAGC palettes follow HyDE automatically on the next open. Do not add
a global launcher style, Rofi script mode or launcher TOML keys to resolve an
application identity problem; the earlier nmrs workaround broke the launcher.
The desktop entry is named Redes and uses the installed network-wireless icon.

HyDE's applet startup override and XDG Hidden entry remain. Its core list still
includes nm-applet; package removal is an owner-authorized narrow exception.
The installer validates the replacement first, installs user files with backups,
then simulates/removes only nmrs and/or network-manager-applet, individually,
with nonrecursive pacman -R. Never remove dependencies or NetworkManager.
`--skip-packages` never changes packages. Official packages need no AUR helper.

Former overlay nmrs palettes, hooks, desktop/icon override and module are removed
by exact paths with backups, preserving unrelated preferences. `restore.sh`
restores only its recorded files, excludes package metadata, and reports manual
package rollback. Reinstall the previous GUI before restoring its settings;
the current nmrs package archive is in the user's private overlay package cache.

## Waybar instance name incident

Do not name a module instance `menu`. During this migration `network#menu`
raised the live bar minimum from 24 to 49 pixels on both displays. Renaming it
`network#connections` restored 24 pixels with identical font, margins and CSS.
Keep this safe instance name and check actual layer height after reload.

## Validation

- Installed official networkmanager-dmenu 2.7.2-1; removed only nmrs 1.6.0-1
  after exact pacman simulation. NetworkManager and nm-connection-editor remain.
- Focused install used the supported lifecycle, with the original nmrs state
  backed up at timestamp 20261022-092012 and later module corrections backed up
  at separate focused timestamps. Package metadata is in the original backup.
- Opened and inspected the live light network menu, desktop entry validated,
  native app-launcher config hashes unchanged. A read-only menu capture verified
  15 Wi-Fi entries sorted by descending strength and cancellation without action.
  No Wi-Fi reconnect or password submission was performed.
- Waybar returned to exactly 24 pixels on both active outputs after renaming the
  conflicting module instance; the five theme switches also preserved that height.
- Seven sandbox migration/rollback tests, 23 hook cases, ./check.sh, full/focused
  dry runs, brightness JSON, fresh interactive Zsh and whitespace validation pass.
  Hyprland configerrors is empty and the active layout remains my-hyde.
- Four LAGC modes were cycled and the original LAGC Tech Light restored. The run
  recorded 136 passing assertions and 4 screenshot failures: Hyprlock covered
  both monitors during the last two samples (confirmed by desktop capture).
  Palette inheritance and height assertions passed throughout. Do not describe
  this run as an entirely passing visual cycle or as a pointer-crossing test.
  Browser UI checks were excluded. Logs are in the private overlay state folder.

## Connected SSID visibility follow-up

The route-selected native network module showed Ethernet details and an empty
SSID while Wi-Fi was also connected. Two native modules then displayed duplicate
network icons, which the owner rejected. Keep one custom/network-status module,
using a read-only libnm snapshot of active physical links (no interface names
hardcoded). Prefer Wi-Fi SSID, then Ethernet profile, then disconnected icon.
The tooltip retains full names, signal/IP data and primary connection; the
22-character native Waybar max-length keeps the bar bounded with end ellipsis.
Escape all runtime SSID/profile/interface text before Pango rendering. Never
change profiles, network routes or credentials to test this display.
The new executable must be installed, snapshotted and restored with the overlay.
Use three spaces between the glyph and label: one space visually touched the
Wi-Fi glyph. The final single-indicator state was observed on both outputs at
24 pixels. The final four-theme run passed 112 assertions with zero failures
(browser checks excluded), restoring LAGC Tech Light. Eight migration/status
sandbox tests and 23 existing hook cases pass; full/focused dry runs and
Hyprland/brightness/Zsh checks pass. The earlier lock-screen-interrupted run
above is historical, not the final acceptance receipt.

## Exit criteria

Revisit if upstream changes executable/config options, signal order, secret
handling or HyDE's Rofi color contract. Do not solve integration by touching
shared HyDE runtime or replacing the recovered app/window launcher.
