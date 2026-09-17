# Solid-first eye comfort profile

- Status: active
- Date: 2026-09-11, amended 2026-09-17 (fully solid surfaces)
- Scope: Hyprland, Waybar, Rofi, Kitty, Dunst, Swaync, NVIDIA, HyDE layer rules

## Context

The glass-panel experiment was visually attractive but the diffuse compositor blur caused eye strain. The owner prefers solid surfaces and, on 2026-09-17, asked to remove the remaining surface alpha everywhere except a small Kitty terminal transparency, in favor of a modern, minimalist, fully opaque desktop following the LAGC Tech Signal Operator palette and WCAG AA contrast.

## Evidence

- The live glass profile used `decoration.blur.enabled = true`, HyDE's layer blur rules and `decoration.glow.enabled = true`.
- The owner explicitly reported that blur did not feel comfortable and preferred solid surfaces with a little transparency; on 2026-09-17 they dropped surface transparency entirely except Kitty.
- Hyprland 0.56.2 accepts `decoration.blur.enabled = false` and layer rules with `blur = false`; `hyprctl configerrors` remained empty after applying the solid profile.
- The brand palette (`lagc-tech/company/docs/brand-system.md`) maps directly onto the theme colors: Midnight `061B2B`, Midnight raised `0A2740`, Frost `EAF7FA`, Frost raised `F7FCFD`, Cobalt `1B5CFF`, Signal Cyan `17D7E8`, Ember `FF7A3D`, Slate `587182`, Ice line `B9D2DB`.
- WCAG audit of the real pairs: Signal Cyan text on Frost measured 1.70:1 (fail) and Cobalt text on Midnight 3.35:1 (fail), so each `waybar.theme` now defines per-theme `wb-ok/info/warn/crit-fg` semantic colors that all measure at least 4.5:1 on `main-bg` (Light: `0B727B`, `1B5CFF`, `C2410C`, `B91C1C`; Dark: `17D7E8`, `6B8CFF`, `FF7A3D`, `F97066`).

## Decision

Use a fully solid profile in the tracked HyDE override. Disable compositor blur, popup/special/input-method blur and inner glow. Keep application windows opaque, palette-driven shadows, rounded corners and the animated border gradient. All user-owned surfaces are opaque: Waybar `bar-bg` and `#pill` at alpha 1.0, Rofi `main-bg` at `FF`, swaync control center and notification popups at `opacity: 1`. The only remaining transparency is Kitty `background_opacity 0.97`. State colors use the per-theme `wb-*-fg` tokens instead of fixed accent hexes so every indicator meets WCAG AA on both themes. Keep the user layer rule matching `rofi`, `notifications`, `swaync`, `logout_dialog` and `waybar` with `blur = false` and `blur_popups = false`, because HyDE's shared layer rules enable blur by default. Do not change Waybar's 22 px layout or its minimum-height workaround.

## Validation

`./check.sh` and `./install.sh --skip-packages` passed. Live state after reload: `decoration:blur:enabled=false`, `decoration:shadow:enabled=true`, `decoration:glow:enabled=false`, Waybar height 22 on both outputs and empty `hyprctl configerrors`. Waybar islands, Rofi, swaync popups and the control center render fully opaque; only Kitty keeps 0.97. State indicators measure WCAG AA on `main-bg` in both themes.

## Exit criteria

Revisit only if the owner requests transparency or blur again. Any future Waybar geometry change still requires the mixed-scale pointer-crossing test.
