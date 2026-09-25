# Pin gtk-application-prefer-dark-theme to the wallbash mode

- Date: 2026-09-25
- Status: active
- Sources: user report ("tengo el dark y se ven light" after enabling "Use GTK" in Chrome/Brave); `~/.local/lib/hyde/theme.switch.sh` (lines 160-164); live screenshot verification of both browsers.

## Context

The user enabled "Use GTK" (`extensions.theme.system_theme = 1`) in Chrome and Brave so browser chrome picks up `Wallbash-Gtk`. With a dark LAGC theme active, both browsers still rendered a light toolbar while web content followed `prefers-color-scheme` correctly. GTK3 clients — including Chromium's GTK mode — decide their light/dark variant from `gtk-application-prefer-dark-theme`, not from `color-scheme`.

## Evidence

- `theme.switch.sh` rewrites `~/.config/gtk-3.0/settings.ini` on every switch but only manages theme-name/icon/cursor/font keys; it never writes `gtk-application-prefer-dark-theme`, so a stale `0` persists on dark themes. The key is ini-only (no `org.gnome.desktop.interface` gsettings equivalent exists on this desktop).
- Chromium in `system_theme: 1` mode reads `Wallbash-Gtk` colors and the dark-preference flag; with the flag at `0` the browser chrome stayed light even though `Wallbash-Gtk` defines dark colors (`theme_bg_color #2B2522` for Calm Dark) and `color-scheme` was `prefer-dark`.
- Live test: setting the flag to `1` plus a `gtk-theme` gsettings re-emit (which forces Chromium to re-read GtkSettings without a restart) flipped Brave's chrome to the dark GTK palette; cycling the theme light→dark flipped it back and forth.
- Wallbash's `<wallbash_mode>` placeholder resolves to `dcol_mode`/`dcol_invt` (post-inversion), i.e. the mode of the *rendered* palette — the correct value for GTK dark preference.

## Decision

- `always/gtk-dark-mode.dcol` renders `<wallbash_mode>` into `~/.config/gtk-3.0/.wallbash-dark-mode`; the paired script `scripts/my-hyde-gtk-dark-mode.sh` rewrites `gtk-application-prefer-dark-theme` inside the ini's `[Settings]` section (insert under the header when missing, create a minimal `[Settings]` file when absent).
- The script no-ops when the value is already correct, so theme-to-theme switches inside one mode do not touch the ini. When the flag actually changes, it re-emits `gtk-theme` via gsettings (`adw-gtk3` → previous value) to force GTK clients to re-evaluate without a restart.
- `install.sh` installs both files and `mkdir -p` `~/.config/gtk-3.0` so wallbash's missing-target-dir skip cannot drop the marker on a fresh machine.

## Validation

- `./check.sh` asserts the `.dcol` header, executable mode, `bash -n`, and the key name in the script.
- Live cycle on the installed system: `theme.switch -s "LAGC Calm Light"` wrote `prefer-dark-theme=0` and Brave rendered fully light; `theme.switch -s "LAGC Calm Dark"` wrote `1` and both Brave and Chrome showed dark GTK chrome without restart (verified by screenshot on each monitor).

## Exit criteria

- If HyDE upstream starts writing `gtk-application-prefer-dark-theme` during `theme.switch`, this hook becomes redundant and both files can be removed from `dotfiles/`, `install.sh` and `check.sh`.
- Restoring does not remove the pinned key from `settings.ini` (it is outside the overlay manifest); a stale `1` there only matters if the user later runs light themes through an un-managed pipeline — delete the key manually to reset.
