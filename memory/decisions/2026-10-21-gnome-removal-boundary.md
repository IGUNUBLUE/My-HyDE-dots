# GNOME removal boundary and file associations

- Status: active
- Date: 2026-10-21
- Scope: package cleanup, GNOME, shared services, MIME defaults, rollback
- Sources: owner authorization to remove unused GNOME while preserving the current Hyprland environment and settings; installed package metadata and reverse dependencies; official HyDE `Scripts/dots/deps.toml` at `fa2fd57a`; [pacman manual](https://man.archlinux.org/man/pacman.8.en).

## Context

The machine uses EndeavourOS/Arch with HyDE and Hyprland. GNOME Shell, its
session and control center remained installed but inactive. Nautilus and
Dolphin both registered `org.freedesktop.FileManager1`, producing D-Bus warnings.
The owner explicitly requested cleaning unused GNOME components.

## Evidence

- The initial recursive removal simulation also selected optional multimedia,
  Bluetooth, location and development libraries. Their lack of a hard package
  dependency does not prove that the current desktop or applications do not
  use them.
- The final explicit transaction removed 43 reviewed packages, about 406.5 MiB
  of installed files: GNOME desktop/session/settings, Mutter, Nautilus, the
  GNOME portal, unused GNOME apps and their exclusive helpers.
- The selected names were checked against both the current official HyDE core
  package list and `packages.arch`; no protected desktop package overlapped.
- Full installed-package and explicit-package lists, pacman's local metadata,
  MIME preferences and all 43 exact-version package archives were backed up
  privately before removal. No user application data or keyring was deleted.
- The global MIME file contained Nautilus's trash handler and File Roller's ZIP
  association alongside unrelated browser and application preferences.

## Decision

- Remove only the reviewed explicit package list with `pacman -R`; do not
  recursively purge all newly orphaned libraries. Keep normal pacsave behavior.
- Preserve `gnome-keyring`, libsecret, GTK3/GTK4, dconf, desktop GSettings schemas,
  GVfs/MTP, PipeWire/WirePlumber, Hyprpolkitagent, the GTK and Hyprland portals,
  Dolphin, Ark, SDDM, and the Qt/KDE dependencies required by HyDE. A GNOME or
  KDE name alone is not a reason for removal.
- Retain shared optional libraries, including Bluetooth OBEX, multimedia
  codecs, location support, Graphviz, WebKitGTK for other applications and
  Python argument completion. Review actual consumers before further cleanup.
- Keep the small portable association policy in
  `dotfiles/.config/hyde/mime-defaults.ini`. `tools/merge-mime-defaults.py` merges
  folder/trash defaults for Dolphin and ZIP defaults for Ark. Other keys,
  comments and additional user associations are preserved.
- Apply through `./install.sh --mime-only` or the regular config module. The
  merged `~/.config/mimeapps.list` is backed up and restored through the normal
  overlay manifest. Do not snapshot the complete personal MIME file.
- Package removal remains a deliberate administrator operation; installing
  this overlay does not automatically uninstall GNOME or any other package.

## Validation

- Exactly the reviewed 43 packages disappeared; no other installed package was
  removed, added or changed in version. `pacman -Dk` passed.
- Only the Hyprland session entries remain; Dolphin is the sole installed
  activation file for `org.freedesktop.FileManager1`.
- System and user managers report no failed units. Hyprland reports no config
  errors. Waybar, idle mitigation, Swaync, XSettings, the keyring and both
  selected portal backends remain active; PipeWire serves audio.
- Brightness status remains valid JSON with internal and external controls.
  Fresh interactive Zsh still resolves the existing user tools.
- Live MIME queries select Dolphin for directories and trash, and Ark for ZIP.
  Browser/PDF/image/text preferences were preserved. A sandbox check verified
  idempotence, comment preservation and retention of unrelated associations.
- The repository checks passed before removal. Live theme validation is
  recorded separately after the transaction.
- The first theme pass had five screenshot failures for Brave page samples;
  the toolbar and other channels passed. Brave alone then passed 50 checks,
  all three browsers passed 29 checks on the original theme, and a full pass
  with more repaint time passed 145/145. The initial sampling cause was not
  proven; no browser profile setting was changed to hide a failure.
- Final service inspection caught the cursor watcher's rate-limit latch during
  the repeated theme tests. Its bounded write coalescing and live cursor-size
  assertions are documented in the active cursor memory; this was repaired
  without altering the cursor theme or sizes.
- After the repair, the full live suite passed 160/160 with the original theme
  restored. System and user managers again reported no failed units; the
  cursor path stayed active and both GTK/XSettings values remained 32.

## Rollback

Reinstall the exact package archives from the private cleanup backup with
`sudo pacman -U` if package rollback is needed. The pre-cleanup explicit-package
list records the original install reasons. Do not restore the whole package
database over a running system. Use `restore.sh` with the focused MIME backup
to restore only the recorded association file. Personal GNOME data remains
untouched, so no profile restoration is needed.

## Exit criteria

Revisit if the owner wants GNOME or a removed application again, if a shared
library has a demonstrated unused status, or if HyDE changes its core package
or file-manager contracts. Any later removal needs a new simulation and an
explicit comparison against current core packages and active consumers.
