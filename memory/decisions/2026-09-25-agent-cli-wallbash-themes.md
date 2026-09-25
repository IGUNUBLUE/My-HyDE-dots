# Wallbash themes for OpenCode and Codex agent CLIs

- Date: 2026-09-25
- Status: active
- Sources: user request ("temas para opencode y codex que se apliquen al cambiar el tema"); installed binaries opencode v2.0.15 and codex-cli 0.156.1; opencode source `packages/theme/src/tui/` (v1-migrate, resolve, themes); codex source `tui` crate (`render/highlight.rs`, `theme/`).

## Context

The user wanted OpenCode and Codex to follow the LAGC Calm/Tech palettes and update automatically on every HyDE theme or mode switch. Both clients support custom themes but use unrelated formats and config keys, and neither palette family exposes its ANSI semantic colors (ember, amber, sage, blues) as `dcol_*` wallbash variables — those live only in each theme's `kitty.theme`.

## Evidence

- OpenCode v2 keeps the TUI theme in `~/.config/opencode/cli.json` as `{"theme": {"name": ...}}` (migrated from v1 `tui.json`). Custom themes load from `~/.config/opencode/themes/*.json` in the V1 flat-semantic format (`defs` + `theme`, 48 keys). `resolveV1` resolves bare hex strings, `$defs` refs, ANSI ints against a *fixed* table, or `{dark, light}` variants — ANSI ints do NOT follow the live terminal palette.
- Codex loads `$CODEX_HOME/themes/<name>.tmTheme` (syntect plist), selected by `[tui] theme` in `config.toml`. `convert_syntect_color` decodes `#RRGGBBAA` foregrounds with alpha `0x00` as ANSI palette indices (`color.r` = index → live terminal palette); backgrounds only accept real RGB (alpha `0x01` = terminal default). Diff line backgrounds come from `markup.inserted`/`markup.deleted` (fallback `diff.inserted`/`diff.deleted`).
- Wallbash's installed `color.set.sh` renders `.dcol` via a pure `sed` substitution pass — there is NO `eval`/heredoc expansion of the body, so escaped values like `\$schema` are written literally (JSON `$schema` keys must therefore be avoided). The target path, however, IS evaluated (`eval target_file="..."`), so `${XDG_CONFIG_HOME:-$HOME/.config}` works in the header line. The template is skipped entirely when the target's parent directory does not exist.
- `always/*.dcol` runs after `theme/*.dcol` on theme, wallpaper and mode switches, so the selector scripts see the freshly rendered `kitty theme.conf` and the active `theme.dcol` palette.
- OpenCode TUI installs a `SIGUSR2` theme refresh (`subscribeThemeSignal`). Daemons and one-shot commands (`serve`, `run`, `acp`) have no handler and would die under the default action, so the selector checks `/proc/<pid>/status` `SigCgt` bit `1 << 11` before signaling.

## Decision

- Tracked templates: `dotfiles/.config/hyde/wallbash/always/opencode.dcol` (JSON V1) and `codex.dcol` (TextMate plist), both named `hyde-wallbash`. Selector scripts: `scripts/my-hyde-opencode-theme.sh` and `my-hyde-codex-theme.sh`.
- Semantic colors reuse the kitty ANSI map (`@ANSIn@` markers spliced from `${HYDE_THEME_DIR}/kitty.theme`, fallback `theme.conf`, fallback the Calm Dark table), so every HyDE theme — not only LAGC — keeps coherent error/warning/success/info roles. In the tmTheme, scope foregrounds use `#NN000000` ANSI-encoded colors so codex follows the live terminal palette directly.
- Diff backgrounds are alpha/blend constructions: opencode gets `#@ANSIn@aa` (alpha hex appended after splice); codex gets `@MIX_1@`/`@MIX_2@` computed as 18% blends of kitty color1/color2 over `dcol_pry1`. Without a readable palette, codex marker lines are deleted and codex falls back to its built-in diff colors.
- Selection is pinned every render (btop pattern): `cli.json` is patched via a JSON round-trip that preserves unknown keys; `config.toml` gets an awk section-scoped `theme = "hyde-wallbash"` edit that creates `[tui]` if missing. `.jsonc` variants keep comments and only rewrite an existing `theme` string. Config `theme` keys are never created outside `cli.json` unless no config exists at all.
- `install.sh` installs the four files, `mkdir -p` both theme directories (wallbash skips missing targets), and `step_apply` renders both templates once via `color.set.sh --single` so a fresh install has themes before the first manual switch.
- No `$schema` key in the opencode JSON (sed-only render writes `\$` literally). The tmTheme omits a `$schema`-equivalent for the same reason.

## Validation

- `./check.sh` simulates the wallbash+selector render: substitutes every placeholder, parses the opencode JSON (48-key coverage asserted) and the tmTheme XML, and checks both `.dcol` headers and selector guards.
- Live cycle verified on the installed system: `theme.switch.sh -s` across LAGC Tech Dark → Calm Light → Calm Dark regenerated both files with the right palettes; `cli.json` diff shows only `theme` changed; `config.toml` kept `[tui] status_line`, `[tui.model_availability_nux]` and `[projects.*]`.
- Sandbox edge tests pass: no kitty theme (fallback table, MIX lines dropped), missing `[tui]` (appended), missing configs (created), absent CLI dirs (early `exit 0`).

## Exit criteria

- If either CLI changes its theme format or config location (OpenCode v3 `ThemeDocument` JSONC, Codex `themes.toml` paths), update the `.dcol` payload and the selector's config edit together; the render pipeline and kitty-ANSI splicing stay valid.
- A user-selected theme via `/theme` is re-pinned on the next HyDE switch by design; relaxing that means deleting the config-pin blocks in both selectors.
- Restoring leaves the generated `hyde-wallbash` theme files and the pinned config keys in place (wallbash outputs are outside the backup manifest); both clients fall back to their defaults if the files are deleted manually.
