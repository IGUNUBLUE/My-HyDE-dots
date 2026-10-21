# Satty native preview

- Status: active
- Date: 2026-10-21
- Scope: Satty, screenshots, mixed-scale displays
- Sources: Satty v0.22.0 README and `src/femtovg_area/imp.rs`; installed Satty 0.22.0 and grim 1.5.0; live capture dimensions and synthetic PNG round trip

## Context

The owner reported blurry screenshot text and requested checking documentation
before relying on a proposed explanation. Satty had no user configuration.

## Evidence

- Satty documents `input-scale = 1.0`. Its renderer initializes `zoom_scale` from
  this setting, defaults to fitting the preview when absent, and renders exports
  separately at the original image resolution, except for an intentional crop.
- Installed grim's help says its default scale is the greatest output scale.
  That did not imply an unwanted upscale in the actual single-output tests:
  both 1920x1080 displays captured at 1920x1080 with or without explicit scale;
  a 400x200 logical region produced 400x200 at scale 1 and 500x250 at scale 1.25.
- An unannotated synthetic 800x400 PNG exported by Satty with default settings
  retained 800x400 dimensions and compared pixel-identical (ImageMagick AE = 0).

## Decision

Track only Satty's documented user config with `input-scale = 1.0` for a preview
at one image pixel per framebuffer pixel. Keep HyDE's capture commands, PNG
output, rendering environment and keybindings. Do not add a grim scale adapter
based on the generic help text. This improves preview clarity; it does not
increase export resolution or fix source text rendering or sharing compression.

## Validation

Official versioned documentation and renderer code reviewed. Default PNG export
and native capture dimensions tested live. The explicit tracked config and the
installed config also exported the synthetic 800x400 fixture with AE = 0. The
installed preview was inspected through a capture of the test window: the zoom
indicator showed 1.00 and text remained readable. `./check.sh`, the full
`./install.sh --dry-run --skip-packages`, the focused dry run and
`git diff --check` passed. Installed with `./install.sh --satty-only`; the backup
manifest records only `.config/satty/config.toml` as newly created. No reload
was required. Hyprland config errors were empty, Waybar was running, brightness
status was valid JSON, and fresh interactive Zsh resolved OMP. The owner still
needs to assess readability with their usual screenshots.

## Exit criteria

Revisit if 100% preview is inconvenient, an installed Satty version changes its
scale semantics, or an original/export comparison demonstrates actual pixel
loss. Recheck capture dimensions after grim or HyDE updates before changing
the capture pipeline.
