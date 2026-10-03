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

## Follow-up 2026-10-03: refresh GTK clients on every switch

- User report: some apps, browsers in particular, did not adopt themes well. A live audit (`tests/live-theme.sh`, throwaway Chrome/Brave profiles with `system_theme=1` plus a Firefox profile kept open across switches) found every system channel correct after every switch — gsettings `color-scheme`/`gtk-theme`/`icon-theme`, portal `org.freedesktop.appearance color-scheme`, `settings.ini`, the `gtk-4.0` link, xsettingsd, `Wallbash-Gtk` css, Kitty, Waybar, Rofi, Qt, rhun — and page `prefers-color-scheme` always right in all three browsers.
- Failure: browser chrome kept the previous palette on same-mode switches (Calm Dark → Tech Dark stayed warm brown, Calm Light → Tech Light stayed parchment) in Chrome, Brave and Firefox, and Firefox could lag one switch behind. Cause: Wallbash rewrites `Wallbash-Gtk/gtk-*/gtk.css` in place, the theme name never changes, and this hook only re-emitted `gtk-theme` when `prefer-dark` flipped. `theme.switch.sh` also changes icons/xsettings before Wallbash renders, so clients that reload on those signals read the old css; `gtk3.dcol`/`gtk4.dcol` copy `gtk.css` to `gtk-dark.css` in the background, racing any reload.
- Fix: the hook now runs its refresh on every switch. It waits (bounded by `MY_HYDE_GTK_SETTLE`, default 3 s) until both `gtk-dark.css` copies equal `gtk.css`, then re-emits `gtk-theme`: first `Wallbash-Gtk-reload`, a symlink alias of the same theme created on demand in `~/.local/share/themes`, then, `MY_HYDE_GTK_GAP` (1 s) later, the real name. The `prefer-dark` write stays conditional.
- Why an alias: with `adw-gtk3` as the intermediate name, Firefox sometimes processed only the first change and stayed on adw-gtk3 (grey `#2E2E32` toolbar on every theme, 1–3 of ~24 switches per run). With the alias a client that stops on the first change still renders the finished palette; a longer gap alone did not remove the failure.
- Tests written first: `tests/hooks.py` reproduced the bug against the old script (same-mode re-emit and re-emit-after-css-copy failed) and passes with the fix; `tests/live-theme.sh` failed 6/100 checks with the old hook installed live (all three browsers on both same-mode switches) and passed 150/150, then 3 × 200/200 with 4 s settle and 100/100 with 2 s settle after installing the fix. The user's own running Chrome and Brave windows followed Calm Dark → Tech Dark → Calm Light → Tech Light correctly. After the alias change, three consecutive live runs with Firefox, Chrome and Brave open passed 196/196 each (7 switches per run, settle-based waits), with no Waybar coredump.
- Out of scope, reported to the user: the Chrome profile "Profile 1" uses a custom colour (`system_theme=0`), so its chrome never follows GTK by design; browser profiles are not modified by the overlay.
