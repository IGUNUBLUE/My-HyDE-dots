# Future cursor consistency and hotspot alignment

- Status: active
- Date: 2026-09-09
- Scope: cursor, HyDE, GTK, XWayland, displays, fractional scaling
- Sources: https://www.gnome-look.org/p/1465392, https://github.com/yeyushengfan258/Future-cursors, https://gitlab.com/Pummelfisch/future-cyan-hyprcursor, https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/, https://hydeproject.pages.dev/en/configuring/config_toml/, live settings and process environment

## Context

Different cursor sources selected different themes and sizes: HyDE, GSettings and user default aliases selected Bibata at 24, while the login environment made Hyprland inherit ArcAurora at 30. This can make the visible shape and hotspot change between compositor surfaces, toolkits and applications. The requested Future-cyan theme must remain portable and accurate across the scale-1.0 external display and scale-1.25 internal display.

## Evidence

- GNOME-Look project 1465392 points to `yeyushengfan258/Future-cursors`, licensed GPL-3.0.
- The pinned upstream commit `587c14d2f5bd2dc34095a4efbb1a729eb72a1d36` is titled “Improve hotzones on some cursors for more consistency” and changes hotspot coordinates for the default arrow, pointer, corners and related shapes.
- Its compiled XCursor payload supplies 24-, 30-, 36- and 48-pixel representations. Live mixed-scale testing accepted logical size 42: 36 was too small, while 48 appeared oversized and blurred on the scale-1.0 external monitor.
- Current HyDE documents `cursor_theme` and `cursor_size` under `[desktop.ui]`; its startup and dynamic reload code invoke `hyprctl setcursor` with those values.
- Hyprland 0.56.2 enables native Hyprcursor by default. The pinned GPLv3 port at `cf4126d17f4520aceb688d8a60daca4a1f0b9e80` supplies 45 native SVG shapes, allowing compositor-native rendering while the original XCursor payload remains available to GTK and XWayland.
- The port's arrow hotspot was `0.203125,0.140625` and link pointer was `0.5,0.25`; the overlay aligns them to the corrected original 64-pixel ratios `12/64,8/64` and `27/64,14/64` respectively.
- Cursor aliases are symlink-rich directory trees. File-only restore traversal cannot faithfully remove new entries and restore an earlier tree, so tree roots require explicit replacement metadata.

## Decision

Vendor the reviewed upstream XCursor `dist/` payload under `dotfiles/.local/share/icons/Future-cursors` and the pinned native port's SVG working source under `cursor-sources/Future-cyan-hyprcursor`, including GPLv3 provenance. Build the native theme locally with `hyprcursor-util` and merge it into the same installed `Future-cursors` directory so one identifier serves Hyprcursor and XCursor clients. Keep the visually accepted logical size 42 in HyDE, both session environment formats, GSettings, and both user-owned default aliases. Install the combined payload as one backed-up tree and preserve XCursor symlinks. Back up the previous GSettings cursor values for rollback. Keep the documented arrow and pointer hotspot adjustments unless controlled visual testing proves a better coordinate.

## Validation

- Run `./check.sh`, `./install.sh --dry-run --skip-packages`, `git diff --check`, and inspect `git diff`.
- Confirm `hyprctl setcursor Future-cursors 42` succeeds and both GSettings cursor values become `Future-cursors` and `42` through the supported configuration flow.
- Confirm the installed combined tree has 111 XCursor entries with no broken symlinks, 45 native `.hlc` shapes, and matching pinned license/provenance checks.
- Confirm `cursor:enable_hyprcursor` is true and explicitly set after installation.
- Verify the default arrow, link pointer, text beam, every resize direction, small click targets and repeated pointer crossing on both active outputs.
- Start a new login session before concluding that every newly launched XWayland or environment-inheriting client uses the new defaults.

## Exit criteria

Revisit when the monitor scales change, HyDE changes its cursor schema, upstream publishes a reviewed hotspot fix, or a reproducible shape-specific hotspot error survives a fresh login with all selectors agreeing. Any custom hotspot patch must document the affected cursor name, scale, old coordinate, new coordinate and visual acceptance evidence.
