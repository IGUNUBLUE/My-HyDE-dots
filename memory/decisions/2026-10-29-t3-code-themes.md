# T3 Code LAGC environment themes

- Status: active
- Date: 2026-10-29
- Sources: [T3 Code appearance documentation](https://github.com/pingdotgg/t3code/blob/main/docs/user/appearance.md), local VSCodium LAGC palettes, installed T3 Code nightly.

## Context

Provide the four existing LAGC palettes to T3 Code while preserving client settings.

## Evidence

T3 Code documents the generated-palette format and environment themes. The installed `t3 theme show` recognized all four files. Environment themes apply only to the primary local environment, not app.t3.codes or additional connections.

## Decision

The four files in `dotfiles/.t3/userdata/themes/` use canvas and accent from the matching VSCodium theme and semantic selection and error colors. The themes module and `--t3-theme-only` install them atomically with normal overlay backups. The user-owned Wallbash hook selects the matching LAGC theme through `t3 theme set` on HyDE changes; other themes fall back to Calm by mode. The CLI uses the local base directory and is optional, so a missing T3 installation is harmless. The command notifies connected clients and applies once when offline clients reconnect.

## Validation

The installed CLI published all four themes. During the live HyDE theme cycle, T3 reported `lagc-tech-dark` and, after restoration, `lagc-tech-light`; the desktop theme test passed 140 checks without browser probes. Visual acceptance in T3 is still needed.

## Exit criteria

Revisit if T3 changes its environment theme schema or the supported selection behavior changes; do not overwrite client settings or unrelated environment themes.
