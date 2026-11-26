# Clean installation validation

## Source baseline

- Overlay before this change: `5c6ffe4`.
- Official HyDE master checked during the audit and implementation:
  `cc824554ac63417d58253ea6764dc0045d963dce` (2026-11-12).
- Official HyDE installation documentation and the current swaync_config dot
  confirm that the config deployment does not install the notification daemon.

## Regression evidence

`TMPDIR=/var/tmp python tests/lifecycle.py` runs real lifecycle commands with
external desktop/package/network stubs. Tests were introduced before each fix:

- Missing Swaync: package was not selected; file-only config accepted its absence.
- No compositor: full live/network-only installs changed targets before failure.
- No Nextcloud: Tech wall.set links were absent. After the fix, ImageMagick itself
  validates both fallback files as PNG at 1920x1080.
- Offline wallpaper reinstall: rollback left the generated Calm PNG in place of
  the prior image.
- Symlink rollback: both regular and dangling original links were omitted.
- First-session daemon handover: the running Dunst state prevented Swaync startup.
- Noninteractive packages: `--yes` did not pass pacman's noninteractive option.

Final local checks passed after the daemon handover changes:

- `TMPDIR=/var/tmp ./check.sh`: 9 network tests, 2 Herdr tests, 9 lifecycle tests,
  28 hook behavior tests, theme/Qt contracts and static/privacy/cursor checks.
- `TMPDIR=/var/tmp ./install.sh --dry-run --skip-packages`: exit 0.
- `git diff --check`: clean.

## Standards review

Independent read-only reviewer checked candidate `b656058` against `5c6ffe4`.
One P1 privacy/backup breach: real ImageMagick followed an existing Tech output
symlink and overwrote the private image it referenced. Restore preserved the
link but could not recover the referent. No additional heuristic findings.

## Spec review

A second independent read-only reviewer checked the same candidate against
`spec.md`. One P1 against requirement 4: the same wallpaper referent corruption.
No other concrete implementation/scope findings. The 9 lifecycle tests passed;
an additional isolated Swaync startup failure correctly propagated exit 1.

## Review correction

Added a real ImageMagick/public install+restore regression; it failed before the
fix. Tech and Calm images are now rendered/downloaded into the installer's own
temporary directory and installed by replacing the recorded destination. The
10-test lifecycle suite passes and the personal image remains byte-identical.
The full `./check.sh`, installer dry run and whitespace check also pass after
this correction (now 10 lifecycle tests).

## Additional dependency check

Source inspection found the same undeclared service dependency for xsettingsd:
the overlay calls add-wants for xsettingsd.service, while current HyDE only
deploys its configuration. The host package has no reverse dependencies. Added
the official Arch package and early config preflight, with two failing-then-
passing lifecycle regressions. The full check passes with 12 lifecycle tests.

## VM acceptance

Used official Arch cloud image `20261115.625457`, SHA256
`dbd02830f6eb0fe07ef6e5edaddbae8b577ce4296d9e79118904704cce0a1f60`, verified
against the official mirror checksum. A separate 40 GiB copy-on-write disk and
NoCloud seed are used with QEMU 11.1.3/KVM, 2 virtual CPUs, 4 GiB RAM and a Virtio
GPU. SSH is forwarded only on loopback; guest access uses a task-owned disposable
key, never the owner's credentials. No graphical environment is preinstalled.

Completed VM stages:

- NoCloud initialization completed without errors. Before installing HyDE,
  pacman confirmed Hyprland, Waybar and Swaync were absent.
- Updated Arch and installed git/base-devel successfully.
- The current overlay's real `--only config,apply --yes --skip-packages`
  invocation without a graphical session exited 1 with the intended guidance;
  the overlay state/backup directory was not created. The installer hash matched
  the host candidate.
- Ran unmodified official HyDE at the pinned commit with its documented
  install/restore/services options, Zsh and no NVIDIA driver in the Virtio VM.
  Dependency installation, dot deployment, twelve stock themes and the initial
  wallpaper cache completed. The completed installer returned 0.
- The guest has a VM-only SDDM autologin fixture selecting Hyprland via UWSM;
  this avoids needing an owner's password and is not part of the overlay.

VM preparation needed two adjustments: the cloud user initially had no password,
so the first official run stopped at chsh. Setting that guest's login shell to
Zsh administratively allowed the repeated official run to complete. The SDDM
autologin fixture must sort after HyDE's own blank Autologin settings. Cloud-init
delays SSH availability until its final stage (around 60 seconds on these boots).
A firmware/device-order recovery was confined to the VM's own NVRAM files.

After reboot, the real Hyprland/UWSM session was active, configuration errors
were empty, and both Waybar and the stock Dunst daemon were running. The official
hyprlock reload migration, which had warned about notification availability
before login, succeeded inside the graphical session.

The published overlay at `9966d5e` was then applied through its full `--yes`
interface inside the session. It returned 0, installed both missing service
dependencies, built the native cursor, installed all four themes without
Nextcloud, installed the logind drop-in, and narrowly removed the old network
applet after its existing simulation. Dunst stopped and Swaync took over.

Post-install and post-reboot checks confirmed:

- Hyprland errors empty, `es,latam`, window opacity 1, Inter Medium 11.
- Waybar running with `my-hyde` selected; Swaync, XSettings, idle and cursor watcher
  active. The initial cursor environment keeps native/legacy sizes 46/32.
- Brightness status was valid JSON; missing external DDC hardware was non-fatal.
- The accepted tracked appearance files were left unchanged in the source.

### Visual acceptance: partial

`BROWSERS=firefox tests/live-theme.sh` ran the complete default five-switch
sequence against the real desktop: **135 assertions passed, 5 failed**. Every
failure was the expected 24-pixel Waybar height; the actual layer was 26 pixels.
Palette propagation, GTK3/libadwaita, Firefox page/chrome, Qt, cursor services,
the network menu and a visible bar on the output passed. The original theme was
restored by the test.

The 26-pixel result persisted after reboot, an explicit bar restart, a LAGC theme
selection, and a temporary Full HD virtual mode. The generated font declaration
was the expected 13 px Atkinson Next SemiBold. Temporary isolated layouts found
the sensor group at 26 pixels and the other five groups at 24; individually the
four sensor modules measured 24. Pair probing was interrupted, so it did not
establish a cause. A temporary sensor font-weight experiment did not help and
is not part of the tracked overlay. See `issues/02-waybar-visual-acceptance.md`.

This run establishes functional installation and persistence, not complete
visual acceptance. It does not validate the owner's physical GPU, mixed-scale
outputs, real pointer crossing, DDC hardware, or controlled dual-monitor unlock.
The existing lock mitigation remains in place.

### Rollback

The temporary CSS experiment was reverted and the diagnostic layout removed.
Before deleting the overlay-created themes, a surviving stock theme was selected.
The previously removed network applet was reinstalled as the documented manual
package step, then the public `restore.sh` ran against the initial full backup
and returned 0.

Nine representative recorded destinations were checked against that backup:
Hyprland, HyDE, Kitty, Zsh, Satty, both cursor aliases, the brightness executable
and the custom layout. Comparisons checked bytes/modes for existing files and
link targets where applicable; paths created by the overlay were absent. The system
logind drop-in created by the overlay was removed. Hyprland errors remained empty
and Waybar was running after restore.

Package and service rollback remain manual by design; this file verification
does not promise to undo unrecorded app or service state. VM-only cleanup returned
the daemon role to stock Dunst separately from file restoration. A fresh
interactive Zsh loaded the HyDE configuration directory; OMP is not installed
in this minimal test machine, as documented for separately installed tools.

## Delivery and acceptance boundary

The installer changes were pushed to `origin/main` at `9966d5e` after the owner's
explicit publication request. The host desktop was never applied or reloaded.
The complete lifecycle suite has 12 passing tests; the full local check, dry run
and whitespace checks pass. Standards and Spec review were both performed, and
their common privacy finding was fixed and regression-tested.

Functional VM install, reboot/persistence and recorded-file restoration passed.
Full visual acceptance remains open on the separate Waybar height finding.
Do not describe this as an entirely passing live-theme run or as physical
dual-monitor, pointer, DDC or lock/unlock acceptance.

## Isolation

The owner's live settings and desktop were not installed, reloaded or changed.
The host temporary filesystem was full during the initial audit, so validation
uses a task-owned temporary directory on another filesystem. No unrelated files
were cleaned up.
