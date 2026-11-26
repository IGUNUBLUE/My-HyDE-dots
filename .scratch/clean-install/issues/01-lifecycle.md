# Make the overlay reproducible after official HyDE

Status: in-progress
Blocked by: none

Implement the acceptance requirements in `../spec.md`, one regression and fix at
a time: Swaync, session preflight, wallpaper fallback, then symlink restoration.
Update README and the repository's compatibility record. Run `./check.sh`, the
installer dry run, whitespace validation, then Standards/Spec review and VM
acceptance. Preserve the accepted desktop settings and private state.
