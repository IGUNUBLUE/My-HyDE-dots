# Make the overlay reproducible after official HyDE

Status: ready-for-human
Blocked by: none

Implement the acceptance requirements in `../spec.md`, one regression and fix at
a time: Swaync, session preflight, wallpaper fallback, then symlink restoration.
Update README and the repository's compatibility record. Run `./check.sh`, the
installer dry run, whitespace validation, then Standards/Spec review and VM
acceptance. Preserve the accepted desktop settings and private state.

## Result

Installer fixes, regression coverage, documentation and independent review are
delivered and published. Real VM installation, reboot/persistence and recorded-
file restore pass. See `../validation.md` for evidence. Visual acceptance is
partial: the live theme run has five Waybar-height failures, tracked in issue 02.
