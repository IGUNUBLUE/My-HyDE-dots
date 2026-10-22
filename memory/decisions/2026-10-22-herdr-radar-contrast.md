# Herdr contrast and external Radar appearance synchronization

- Status: active
- Date: 2026-10-22
- Scope: Herdr 0.9.5, external Herdr Radar 1.3.14, Mira 0.5.2, LAGC terminal themes
- Sources: installed plugin source/config; official Herdr v0.9.5 configuration documentation and src/app/mod.rs resolve_effective_theme; live process/config checks.

## Context

The owner reported low-contrast tab/new-tab-dialog text after desktop theme
validation. Herdr uses the host terminal palette, with personal mode-specific
contrast overrides. Radar is an external plugin; do not treat it as owned code,
patch its installed package or fork it to resolve a personal configuration issue.

## Evidence

- Herdr applies custom.light/custom.dark only when auto_switch is true, as
  documented and confirmed in v0.9.5 resolve_effective_theme.
- Installed Radar managed-config.js applyAppearance rewrites auto_switch=false.
  Its timestamp coincided with the earlier theme cycle. A causal trigger from
  that cycle is plausible; the earlier captured full config is not a live UI trace.
- Mira supplies native light/dark reports. Recent network commits did not change
  the Kitty ANSI palettes. The installed Herdr client and server remain 0.9.5.
- Radar documents follow_appearance=false to hand theme ownership to Herdr while
  retaining its other features. Its resident daemon launches a fresh theme-sync
  child, which reads the user's preference on every attempt.

## Decision

Declare only appearance preferences in herdr-theme.toml and herdr-radar.toml.
Keep Herdr native auto_switch and terminal light/dark themes; preserve the
previous personal mode-specific contrast corrections. Disable only Radar's
follow_appearance writer. Never capture its full config, keybindings, workspaces,
plugin state or credentials in this repository.

Merge via --herdr-theme-only or the optional normal config step. Prepare both
outputs before changing either; preserve existing permissions and unrelated keys.
Back up through the overlay manifest and reload configuration with the documented
Herdr command. Never stop/restart Herdr or Mira to apply these preferences.
Snapshot only the declared keys. Restore only manifest paths and reload config.
The first live recovery backup is the private timestamp 20261022-120221.

## Validation

The installed Herdr config check passed, config reload returned applied without
diagnostics, and the client/server PIDs stayed unchanged. The plugin's fresh
configuration reads followAppearance=false and theme-sync explicitly reports no
operation. Active tabs were observed with readable light text on blue after reload;
the original new-tab modal was already closed, so its final visual acceptance
remains with the owner. Merge/snapshot preservation, array handling, idempotence,
failure before partial writes, permissions and focused restore are tested in a
fake HOME. No desktop theme cycle or user session restart is needed for this fix.

## Exit criteria

Revisit when Radar supports Herdr's native mode subtables without disabling
auto_switch, when Herdr changes its resolution contract, or when the owner
requests another theme. Keep external plugin installation code untouched.
