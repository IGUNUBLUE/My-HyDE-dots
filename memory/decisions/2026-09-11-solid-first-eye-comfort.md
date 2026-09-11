# Solid-first eye comfort profile

- Status: active
- Date: 2026-09-11
- Scope: Hyprland, Waybar, Rofi, Kitty, Dunst, NVIDIA, HyDE layer rules

## Context

The glass-panel experiment was visually attractive but the diffuse compositor blur caused eye strain. The owner prefers solid surfaces with only slight transparency. The Waybar islands should remain as previously accepted; only the compositor blur layer is removed.

## Evidence

- The live glass profile used `decoration.blur.enabled = true`, HyDE's layer blur rules and `decoration.glow.enabled = true`.
- The owner explicitly reported that blur did not feel comfortable and preferred solid surfaces with a little transparency.
- Hyprland 0.56.2 accepts `decoration.blur.enabled = false` and layer rules with `blur = false`; `hyprctl configerrors` remained empty after applying the solid profile.
- The accepted near-solid surface values are now: Waybar islands `alpha(@main-bg, 0.99)`, Rofi background alpha `F7`, tooltip alpha `1.0`, and Kitty `background_opacity 0.97`.

## Decision

Use a solid-first profile in the tracked HyDE override. Disable compositor blur, popup/special/input-method blur and inner glow. Keep application windows opaque, palette-driven shadows, rounded corners, the animated border gradient and the small surface alpha values. Add one user layer rule matching `rofi`, `notifications`, `swaync`, `logout_dialog` and `waybar` with `blur = false` and `blur_popups = false`, because HyDE's shared layer rules enable blur by default. Do not change Waybar's 22 px layout or its minimum-height workaround.

## Validation

`./check.sh` and `./install.sh --skip-packages` passed. Live state after reload: `decoration:blur:enabled=false`, `decoration:shadow:enabled=true`, `decoration:glow:enabled=false`, Waybar height 22 on both outputs and empty `hyprctl configerrors`. The generated Waybar, Rofi and Kitty files retain their small alpha values.

## Exit criteria

Revisit only if the owner requests glass/blur again, or if a future Hyprland/HyDE release provides a non-diffuse transparency effect that does not cause eye strain. Any future Waybar geometry change still requires the mixed-scale pointer-crossing test.
