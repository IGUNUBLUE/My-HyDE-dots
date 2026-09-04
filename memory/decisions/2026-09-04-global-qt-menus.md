# Global Qt menu preferences

- Status: active
- Date: 2026-09-04
- Scope: Qt, Kvantum, Wallbash

## Context

The owner requested persistent menu preferences across all themes. This replaces the Material Sakura Polished variant.

## Evidence

HyDE's Wallbash README documents target|command post-processing. Installed and upstream color.set.sh use the matching kvconfig.dcol header even when rendering a theme's kvconfig.theme. globalcontrol.sh searches user Wallbash directories first.

## Decision

Keep preferences in dotfiles/.config/hyde/qt-menu.ini and the callback in dotfiles/.local/bin/my-hyde-qt-menu. Installation prepares a user template from installed upstream, retaining its body and adding the callback. Only menu keys are changed in generated Kvantum output through this documented callback; preserve colors and SVG references. Reinstall after HyDE updates to refresh the template. GTK and browser-owned menus are outside this scope. Shadows depend on the active theme SVG.

## Validation

Live switches to Mocha, Latte and original Material Sakura retained icons and margins while window colors changed to #1E1E2E, #EFF1F5 and #faf4ed. Left Material Sakura active. These were configuration checks, not visual acceptance in Dolphin. Tests cover palette preservation, duplicate sections and idempotence. Focused --qt-menu-only installation records all three installed files for rollback.

## Exit criteria

Revisit if Wallbash changes directory precedence, callbacks or Kvantum target. After rollback, reselect the current theme to regenerate output. Never replace shared HyDE runtime for this customization.
