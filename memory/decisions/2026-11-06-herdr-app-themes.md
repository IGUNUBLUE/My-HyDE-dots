# Herdr desktop app LAGC themes following HyDE

- Status: active
- Date: 2026-11-06
- Scope: herdr-app 0.1.13 (with herdr-core `hc`), LAGC themes, Wallbash always/ hooks
- Sources: https://herdr.dev/; the `AGENTS.md`, `herdr.d.ts` and `herdr-app commands` the app writes in `~/.config/herdr-app`; DeepWiki for `herdrdev/herdr-app`; live tests on 2026-11-06.

## Context

The owner installed the new Herdr desktop app and wanted the LAGC themes in its settings, applied automatically when switching themes with the HyDE selector. It is separate from the Herdr TUI of the Radar memory; no config or state is shared.

## Evidence

- `themes/<name>.json` holds `background`, `foreground`, `selection`, `cursor`, 16 `ansi` colors and optional `colors` overrides. `settings.json` `theme` takes a name or `{light, dark}`; edits apply live (observed: Tech Light, Tech Dark and Calm Light rendered without restart).
- The in-app picker and `app.theme` write a `{light, dark}` pick to `layouts/.state/<layout>.json`, which outranks `settings.json`. The app keeps that pick in memory and rewrites the file, so deleting the key on disk does not clear it. Only `layout.reset` cleared it; the three click values (sidebar 325, panel 372, Changes tab) were restored with `layout.resize` and `layout.select`, and the old layout file is kept as `layouts/main.json.old-*`.
- A window on a workspace shown on no monitor is not redrawn; `herdr-app shot` then returns a stale, byte-identical frame.
- With the Lua parser, `hyprctl dispatch 'hl.dsp.focus({ workspace = N })'` is the working syntax.

## Decision

- Four generated themes tracked under `dotfiles/.config/herdr-app/themes/`, produced by `tools/herdr-app-themes.py` from the Kitty and rhun palettes and validated by `check.sh`.
- `always/herdr-app-theme.dcol` writes the mode to `~/.config/herdr-app/.wallbash-mode` and runs `my-hyde-herdr-app-theme.sh`, which sets a single theme name in `settings.json` (LAGC exact match, Calm light/dark fallback, never a missing theme). A single name avoids depending on the system appearance. If an in-app pick exists and the app runs, it pushes the family through `app.theme`; it never creates a pick.
- `install_herdr_app_theme` (in `step_themes` and `--herdr-app-theme-only`) skips when `~/.config/herdr-app` does not exist. `restore.sh --herdr-app-theme-only` removes only overlay files.

## Validation

`tests/hooks.py` (28 tests, including mapping, fallback, idempotence, missing theme, unparseable file, no-app and pick sync), `tools/herdr-app-themes.py --check`, `./check.sh`. Live: `hydectl theme set` over all four LAGC themes produced the matching `settings.json` theme each time, and the running app rendered Tech Light and Tech Dark. The full `tests/live-theme.sh` was not run.

## Exit criteria

Revisit if Herdr changes the theme file schema or precedence, adds a way to clear a pick without `layout.reset`, or if the owner wants a `{light, dark}` pair driven by system appearance.
