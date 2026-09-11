# Glass panels with opaque windows

- Status: superseded
- Date: 2026-09-11
- Scope: Hyprland, Waybar, Rofi, Kitty, btop, Wallbash, NVIDIA, HyDE Lua parser

## Context

The owner asked for a visually striking desktop without leaving HyDE's supported override points. The overlay previously ran flat on purpose: `decoration.blur.enabled = false`, no shadow, a `class = ".*"` window rule with `opaque = true`, and a layer rule that disabled the blur HyDE already applies to `rofi`, `notifications`, `waybar` and `logout_dialog`. Web research produced guides for `latest git` blur variants that are not in the installed release.

## Evidence

- `hyprctl getoption` on Hyprland 0.56.2: `decoration:blur:*`, `decoration:shadow:{sharp,color_inactive,scale}`, `decoration:glow:*`, `decoration:motion_blur:*`, `general:snap:*`, `rounding_power` exist; `decoration:blur:variant` and `decoration:wobble:*` are `no such option`, and setting them fails with `unknown config key`.
- `hyprctl keyword` returns `keyword can't work with non-legacy parsers. Use eval`; `hyprctl eval 'hl.config({...})'` applies options and `hyde-shell -r` reverts them.
- A/B screenshots of a 0.55-opacity floating terminal at the same crop: with blur enabled the wallpaper behind it is smooth; with `blur.enabled = false` the editor text behind the window stays sharp and readable through the terminal.
- `hyde-shell animations --set end4` plus `[hyprland.anim] duration_scale = 1.5` in `config.toml` moved `windowsIn` from speed 3.0 to 4.5 and `workspaces` from 7.0 to 10.5, proving the preset reads `config.toml` before `hyprland.lua` runs.
- HyDE's `layer_rules.lua` already declares `blur = true` and `ignore_alpha = 0` for the launcher, notification, bar and logout namespaces.

## Decision

Keep application windows fully opaque and take the glass from surfaces that are translucent by design: Waybar islands, the frosted Rofi launcher, Dunst and Kitty at 0.90. Tracked state: `hyprland.lua` enables blur (size 6, 2 passes, popups, special, input methods), shadow (range 22, midnight colors, offset 0/6) and glow (cyan), sets `rounding = 12` with `rounding_power = 2.4`, animates only `borderangle` with a local `user_linear` curve, and no longer carries a global animation override or any rule that forces `opaque` or disables layer blur. Animation speed is scaled from `config.toml` through `[hyprland.anim] duration_scale = 0.9`. `always/rofi-opaque.dcol` became `always/rofi-frosted.dcol` (main background alpha `E6`) and `always/btop.dcol` plus `scripts/my-hyde-btop.sh` generate and select a `hyde-wallbash` btop theme. Do not follow the wiki's blur variants until Hyprland ships them in a release. Waybar keeps the islands' 0.92 background but overrides HyDE's layer threshold (`ignore_alpha = 0.05` instead of `0`), because HyDE's value blurs the whole bar rectangle and leaves a hazy band between the islands; native-resolution captures show the gaps returning to the untouched wallpaper. The screen shader stays a per-machine choice made with `hyde-shell shaders --select`; `vibrance` is enabled locally (a 1.7 % RMSE saturation lift, no clipping) and `wallbash.frag` was rejected because it tints the whole render, not just the blur.

## Validation

`./check.sh`, `./install.sh --dry-run --skip-packages` and `./install.sh --skip-packages` passed. Live checks after the reload: `decoration:blur:enabled/shadow:enabled/glow:enabled` true, `rounding = 12`, `borderangle` overridden with `user_linear` at speed 60, empty `hyprctl configerrors`. Screenshots confirmed the blurred backdrop, the frosted Rofi launcher and a btop window rendering the generated light palette. Animation preset restored to `01-default` after the duration-scale experiment.

## Exit criteria

Revisit when a release adds `decoration.blur.variant` or `decoration.wobble` (re-check with `hyprctl getoption` first), when HyDE changes the order in which `config.toml` and the animation preset load (the `duration_scale` key depends on that order), or if the laptop GPU shows sustained load from blur, shadow and glow together. Waybar geometry rules still apply: any change to bar padding or borders must repeat the mixed-scale pointer-crossing test before acceptance.
