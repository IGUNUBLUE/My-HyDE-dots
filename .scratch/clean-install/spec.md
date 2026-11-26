# Reliable installation after official HyDE

Status: ready-for-human

Implementation and publication are complete. Functional VM installation and
recorded-file rollback pass; final visual acceptance remains open on the
Waybar finding in `issues/02-waybar-visual-acceptance.md`.

## Agreed scope

On a minimal Arch Linux system with official HyDE installed, the overlay must
install its declared notification daemon, reject live application without a
reachable Hyprland session before changing targets or packages, provide usable
wallpapers for every LAGC theme without Nextcloud, and restore replaced symbolic
links. Preserve the accepted visual configuration, private data and upstream
runtime ownership.

## Acceptance

Tests exercise the public `install.sh` and `restore.sh` commands in isolated HOME
and XDG directories. Fake external commands represent the package manager and
desktop services, never the lifecycle logic under test. Each regression must
fail before its fix. Wallpaper tests additionally validate a real generated image.

1. Full package selection includes Swaync; config installation with missing
   Swaync refuses before writing targets. On initial application, stop the
   upstream Dunst daemon before starting Swaync; propagate startup failure.
   The package step honors the documented `--yes` option.
   The overlay's XSettings service also has an explicit package dependency and
   is checked before file-only config installation.
2. A missing/unreachable graphical session fails before packages, backups or
   configuration are changed. Dry runs and file-only selections still work.
3. All four LAGC themes have valid wallpaper links without private source images;
   generated fallback files are recorded for rollback, including repeat installs.
4. Restore recovers symlinks, including dangling links, and preserves unrelated
   files and the contents of symlink referents.
5. README documents HTTPS cloning, the reboot/login sequence, separately
   installed applications and post-install acceptance.
6. Required static/sandbox checks pass. A separate VM acceptance attempts minimal
   Arch -> official HyDE -> overlay -> reboot -> desktop checks -> restore.
   Record exact upstream versions and distinguish limitations from passes.

## Delivery

Review Standards and Spec separately against the pre-change commit. Commit
after checks and publish to `origin/main`, as authorized by the owner. Do not
install the changes on the owner's desktop.
