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

Standards/Spec review and VM results are appended below.

## Isolation

The owner's live settings and desktop were not installed, reloaded or changed.
The host temporary filesystem was full during the initial audit, so validation
uses a task-owned temporary directory on another filesystem. No unrelated files
were cleaned up.
