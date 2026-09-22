# VSCodium LAGC Calm themes; Kiro/Zed support removed

- Date: 2026-09-22
- Status: active
- Sources: user request; Kiro theme structure reused as the VSIX template; palette taken from the tracked LAGC Calm `theme.dcol`/`kitty.theme` files.

## Context

The user replaced editor support: Kiro and Zed were dropped, and a VSCodium theme family based on **LAGC Calm** (not Tech) was requested. VSCodium consumes the same VS Code-compatible extension format Kiro used, so the extension skeleton and the validate/package tool were reused.

## Evidence

- `codium --install-extension` accepted the generated VSIX and `codium --list-extensions` shows `igunublue.lagc-themes`; all four contributed themes (`LAGC Calm Dark`, `LAGC Calm Light`, `LAGC Tech Dark`, `LAGC Tech Light`) registered in `~/.vscode-oss/extensions`.
- `tools/package-vscodium-theme.py --check` validates theme name/type, all hex colors, structural border keys, tokenColors and semanticTokenColors; the themes define ~390 workbench colors and 27 TextMate rules each because undefined keys fall back to VSCode cool-toned defaults.
- `check.sh`, `install.sh --dry-run --skip-packages`, `git diff --check` and `bash -n` on all lifecycle scripts pass with no kiro/zed references left.

## Decision

- Extension source lives at `dotfiles/.local/share/vscodium/themes/lagc-calm/` (`package.json`, two `themes/*-color-theme.json`, README). No VSIX or `~/.vscode-oss/extensions` runtime state is tracked.
- `install.sh` flag is `--vscodium-theme-only`; the full install calls it non-fatally when `codium` is on PATH. `restore.sh --vscodium-theme-only` runs `codium --uninstall-extension igunublue.lagc-themes`.
- Palette mapping: Tech cyan accent `#17D7E8` → sage `#A9C080` (dark) / `#5C7040` (light); Tech blue `#1B5CFF` → sage `#7F9A5E` (dark) / `#5C7040` (light); amber `#D4A55C` is the attention/find color; terracotta `#D67A6E` (dark) / `#9E4F43`/`#B05A4E` (light) is error/deleted. Terminal ANSI colors match `kitty.theme` exactly (color0..color15).
- Kiro support fully removed: `dotfiles/.local/share/kiro/`, `tools/package-kiro-theme.py`, the `kiro` shell-integration block in `dotfiles/.config/zsh/user.zsh`, and the `--kiro-theme-only` lifecycle paths. Zed support removed: `dotfiles/.config/zed/`, `tools/merge-zed-settings.py`, `--zed-theme-only` paths, and the `update-snapshot.sh` Zed copy line.
- `install.sh` runtime cursor apply lines were still pinning size 42 after the size-46 change; corrected to 46 (setcursor, gsettings cursor-size, XCURSOR_SIZE, HYPRCURSOR_SIZE).

## Validation

- `python tools/package-vscodium-theme.py --check` passes; `codium --list-extensions` lists the extension after live install.
- `./check.sh` passes; `./install.sh --dry-run --skip-packages` shows the package+install commands; `git diff --check` clean.
- Theme visual acceptance in the editor requires the user to open VSCodium and pick a theme via Preferences: Color Theme. Coverage intentionally includes symbolIcon.*, editorBracketHighlight.*, minimap, peekView, notifications, menus, suggest/hover widgets, bracket-pair guides and common markup/JSON/CSS/HTML scopes; remaining unlisted keys (notebook.*, scm.*, chat/inlineChat AI surfaces) still fall back to VSCodium defaults and can be added on demand.

## Exit criteria

- Revisit if the user wants LAGC Tech variants in VSCodium (extend the THEMES map and add theme JSONs), or if VSCodium theme selection should be written into `settings.json` automatically.

## Follow-up: LAGC Tech pair added

- The extension was renamed to `igunublue.lagc-themes` and now ships all four themes; `restore.sh` uninstalls both the new and the legacy `igunublue.lagc-calm-themes` identifier.
- LAGC Tech Dark/Light reuse the full Calm coverage (391 workbench colors, 27 token rules, semantic tokens) with the Tech palette transformed for eye comfort: every hex passes a HSL transform that desaturates ~28% and clamps extreme lightness, applied consistently to `theme.dcol`, `hypr.theme`, `kitty.theme`, `rofi.theme` and `waybar.theme` in both tracked and live copies.
- Tech terminal ANSI colors keep the original Tech hues, transformed the same way, instead of inheriting Calm sage tones.
