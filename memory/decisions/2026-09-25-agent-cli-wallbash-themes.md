# Wallbash themes for OpenCode, Codex and Oh My Pi agent CLIs

- Date: 2026-09-25 (OMP added 2026-09-26)
- Status: active
- Sources: user request ("temas para opencode y codex que se apliquen al cambiar el tema"); installed binaries opencode v2.0.15 and codex-cli 0.156.1; opencode source `packages/theme/src/tui/` (v1-migrate, resolve, themes); codex source `tui` crate (`render/highlight.rs`, `theme/`); Oh My Pi omp/18.3.5 and upstream `docs/theme.md` (can1357/oh-my-pi).

## Context

The user wanted OpenCode and Codex to follow the LAGC Calm/Tech palettes and update automatically on every HyDE theme or mode switch. Both clients support custom themes but use unrelated formats and config keys, and neither palette family exposes its ANSI semantic colors (ember, amber, sage, blues) as `dcol_*` wallbash variables — those live only in each theme's `kitty.theme`. The same request was later extended to Oh My Pi (omp), a third agent CLI with its own JSON theme schema.

## Evidence

- OpenCode v2 keeps the TUI theme in `~/.config/opencode/cli.json` as `{"theme": {"name": ...}}` (migrated from v1 `tui.json`). Custom themes load from `~/.config/opencode/themes/*.json` in the V1 flat-semantic format (`defs` + `theme`, 48 keys). `resolveV1` resolves bare hex strings, `$defs` refs, ANSI ints against a *fixed* table, or `{dark, light}` variants — ANSI ints do NOT follow the live terminal palette.
- Codex loads `$CODEX_HOME/themes/<name>.tmTheme` (syntect plist), selected by `[tui] theme` in `config.toml`. `convert_syntect_color` decodes `#RRGGBBAA` foregrounds with alpha `0x00` as ANSI palette indices (`color.r` = index → live terminal palette); backgrounds only accept real RGB (alpha `0x01` = terminal default). Diff line backgrounds come from `markup.inserted`/`markup.deleted` (fallback `diff.inserted`/`diff.deleted`).
- Wallbash's installed `color.set.sh` renders `.dcol` via a pure `sed` substitution pass — there is NO `eval`/heredoc expansion of the body, so escaped values like `\$schema` are written literally (JSON `$schema` keys must therefore be avoided). The target path, however, IS evaluated (`eval target_file="..."`), so `${XDG_CONFIG_HOME:-$HOME/.config}` works in the header line. The template is skipped entirely when the target's parent directory does not exist.
- `always/*.dcol` runs after `theme/*.dcol` on theme, wallpaper and mode switches, so the selector scripts see the freshly rendered `kitty theme.conf` and the active `theme.dcol` palette.
- OpenCode TUI installs a `SIGUSR2` theme refresh (`subscribeThemeSignal`). Daemons and one-shot commands (`serve`, `run`, `acp`) have no handler and would die under the default action, so the selector checks `/proc/<pid>/status` `SigCgt` bit `1 << 11` before signaling.
- Oh My Pi (`omp`, Oh My Pi — NOT Oh My Posh) loads custom themes from `${PI_CODING_AGENT_DIR:-~/.omp/agent}/themes/<name>.json`, validated against `themeJsonSchema` with 66 required `colors` tokens plus optional `vars` (recursive refs), `symbols` and `export` sections; values accept `#RRGGBB`, ANSI index ints, `""` (terminal default) or var refs. Theme selection is persisted in `~/.omp/agent/config.yml` under `theme.dark`/`theme.light`; OMP picks a slot itself from terminal background luminance (OSC 11). Interactive sessions watch the ACTIVE theme's file only and hot-reload it on change, so regenerating the same filename updates running TUIs without a signal — but sessions started before the pin keep their old theme until restart or a manual pick.

## Decision

- Tracked templates: `dotfiles/.config/hyde/wallbash/always/opencode.dcol` (JSON V1), `codex.dcol` (TextMate plist) and `omp.dcol` (OMP JSON schema), all named `hyde-wallbash`. Selector scripts: `scripts/my-hyde-opencode-theme.sh`, `my-hyde-codex-theme.sh` and `my-hyde-omp-theme.sh`.
- Semantic colors reuse the kitty ANSI map (`@ANSIn@` markers spliced from `${HYDE_THEME_DIR}/kitty.theme`, fallback `theme.conf`, fallback the Calm Dark table), so every HyDE theme — not only LAGC — keeps coherent error/warning/success/info roles. In the tmTheme, scope foregrounds use `#NN000000` ANSI-encoded colors so codex follows the live terminal palette directly.
- Diff backgrounds are alpha/blend constructions: opencode gets `#@ANSIn@aa` (alpha hex appended after splice); codex gets `@MIX_1@`/`@MIX_2@` computed as 18% blends of kitty color1/color2 over `dcol_pry1`. Without a readable palette, codex marker lines are deleted and codex falls back to its built-in diff colors.
- Selection is pinned every render (btop pattern): `cli.json` is patched via a JSON round-trip that preserves unknown keys; `config.toml` gets an awk section-scoped `theme = "hyde-wallbash"` edit that creates `[tui]` if missing. `.jsonc` variants keep comments and only rewrite an existing `theme` string. Config `theme` keys are never created outside `cli.json` unless no config exists at all.
- `install.sh` installs the template/script pairs, `mkdir -p` each theme directory (wallbash skips missing targets), and `step_apply` renders each template once via `color.set.sh --single` so a fresh install has themes before the first manual switch.
- No `$schema` key in the opencode JSON (sed-only render writes `\$` literally). The tmTheme and the OMP JSON omit `$schema` for the same reason.
- OMP gets ONE `hyde-wallbash` theme file pinned to BOTH `theme.dark` and `theme.light` — wallbash only knows the active palette, so whichever slot OMP's luminance probe picks yields the current colors. `my-hyde-omp-theme.sh` resolves `@ANSIn@` like opencode and generalizes the codex mixer to `@MIX_n@` = ANSI n at 18% over `dcol_pry1` for `toolPendingBg`/`toolSuccessBg`/`toolErrorBg`; the config edit is an awk section rewrite of the top-level `theme:` map that also migrates the legacy flat `theme: name` form and inserts missing slots. No reload signal is sent — OMP's own file watcher hot-reloads the active custom theme.
- Wallbash post-scripts run asynchronously after the body write; reading the target file immediately after `color.set.sh` returns can still show unresolved markers — check generated state after a short settle, not inline.

## Validation

- `./check.sh` simulates the wallbash+selector render: substitutes every placeholder, parses the opencode JSON (48-key coverage asserted) and the tmTheme XML, and checks both `.dcol` headers and selector guards.
- Live cycle verified on the installed system: `theme.switch.sh -s` across LAGC Tech Dark → Calm Light → Calm Dark regenerated both files with the right palettes; `cli.json` diff shows only `theme` changed; `config.toml` kept `[tui] status_line`, `[tui.model_availability_nux]` and `[projects.*]`.
- Sandbox edge tests pass: no kitty theme (fallback table, MIX lines dropped), missing `[tui]` (appended), missing configs (created), absent CLI dirs (early `exit 0`). OMP YAML edges verified: flat `theme:` scalar expanded to the nested map, missing slot inserted, missing section appended, non-theme keys preserved.
- Live cycle verified 2026-09-26: `theme.switch.sh -s` Tech Light → Calm Dark → Tech Dark regenerated `~/.omp/agent/themes/hyde-wallbash.json` with the correct palettes (`#2B2522`/`#E9DFCE`/`#A9C080` on Calm Dark, `#0C1C28`/`#DDEEF2`/`#34BFCB` on Tech Dark); `config.yml` kept every key with only the theme slots pinned.

## Exit criteria

- If either CLI changes its theme format or config location (OpenCode v3 `ThemeDocument` JSONC, Codex `themes.toml` paths, OMP `themeJsonSchema` token changes), update the `.dcol` payload and the selector's config edit together; the render pipeline and kitty-ANSI splicing stay valid.
- OMP sessions running before the pin keep their previous theme until restart or a manual `/theme` pick — only after that does the file watcher take over; requiring zero restarts would need an OMP-side config reload hook that does not exist.
- A user-selected theme via `/theme` is re-pinned on the next HyDE switch by design; relaxing that means deleting the config-pin blocks in both selectors.
- Restoring leaves the generated `hyde-wallbash` theme files and the pinned config keys in place (wallbash outputs are outside the backup manifest); both clients fall back to their defaults if the files are deleted manually.
