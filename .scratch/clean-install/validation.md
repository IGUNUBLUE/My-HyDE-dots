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

In progress: official Arch cloud image `20261115.625457`, SHA256
`dbd02830f6eb0fe07ef6e5edaddbae8b577ce4296d9e79118904704cce0a1f60`, verified
against the official mirror checksum. A separate 40 GiB copy-on-write disk and
NoCloud seed are used with QEMU 11.1.3/KVM, 2 virtual CPUs, 4 GiB RAM and a Virtio
GPU. SSH is forwarded only on loopback; guest access uses a task-owned disposable
key, never the owner's credentials. No graphical environment is preinstalled.

## Isolation

The owner's live settings and desktop were not installed, reloaded or changed.
The host temporary filesystem was full during the initial audit, so validation
uses a task-owned temporary directory on another filesystem. No unrelated files
were cleaned up.
