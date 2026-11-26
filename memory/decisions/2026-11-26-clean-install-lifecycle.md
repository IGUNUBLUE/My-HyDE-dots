# Clean installation lifecycle boundaries

- Status: active
- Date: 2026-11-26
- Scope: install.sh, restore.sh, packages.arch, wallpapers, clean installation
- Sources: HyDE master cc824554ac63417d58253ea6764dc0045d963dce; official installation documentation; tests/lifecycle.py

## Context

An audit of minimal Arch -> official HyDE -> personal overlay found dependencies
on the existing desktop that the static checks did not cover. The owner approved
fixing the installer, rollback and documentation, followed by isolated tests,
Standards/Spec review and a separate VM acceptance attempt.

## Evidence

- Official HyDE installs Dunst; its swaync_config dot deploys configuration only
  and explicitly leaves daemon installation opt-in. The overlay suppresses the
  Dunst startup and requires swaync.service, but had not declared the package.
- A missing Hyprland session previously failed after target files were replaced.
- Without the private Tech source image, neither Tech theme had a wall.set link;
  HyDE's get_themes skipped both themes. Calm had a public/offline fallback.
- Offline Calm reinstalls wrote PNG fallback files without backing up the PNG.
- Restore traversed regular files only, silently omitting backed-up symlinks.

## Decision

Declare Swaync and check it before installing config without packages. Validate
compositor connectivity before full live installation or network-only changes,
including before the optional gum bootstrap. Dry runs and explicit file-only
module selections remain available without a session.

The first upstream graphical session can still have Dunst running. Stop its
HyDE notification unit, its user unit and remaining user-owned Dunst process
before starting Swaync; daemon startup errors must fail the apply step. Honor
`--yes` for the full pacman package transaction as for the network transaction.

Keep Tech photo tinting when a source exists; otherwise generate deterministic
gradients within the theme's own wallpapers directory. Record the actual Calm
fallback filename. Restore recorded links as links and replace destination files
without following a symlink into an unrelated referent.

Keep lifecycle regression tests at the real CLI boundary in an isolated HOME.
Only external package/network/desktop commands are faked. Preserve upstream
runtime ownership, accepted visuals, idle mitigation and the logind allowlist.

## Validation

Each regression failed before its fix. The lifecycle suite checks daemon package
selection and early refusal, missing/stale sessions, file-only and dry-run modes,
all four wallpaper links, valid Tech PNG dimensions, offline wallpaper rollback,
and both regular and dangling original symlinks. Full suite and VM acceptance
results are recorded separately in `.scratch/clean-install/validation.md`.

## Exit criteria

Revisit if HyDE changes daemon selection, session startup, theme discovery or
the documented extension points. A complete fresh-install acceptance additionally
requires actual Arch/HyDE package installation, a rebooted graphical session and
rollback; sandbox command stubs alone do not satisfy that requirement.
