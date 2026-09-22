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
- Its compiled XCursor payload supplies 24-, 30-, 36- and 48-pixel representations. Live mixed-scale testing accepted logical size 46 (2026-09-22, up from 42): 36 was too small, while 48 appeared oversized and blurred on the scale-1.0 external monitor.
- Current HyDE documents `cursor_theme` and `cursor_size` under `[desktop.ui]`; its startup and dynamic reload code invoke `hyprctl setcursor` with those values.
- Hyprland 0.56.2 enables native Hyprcursor by default. The pinned GPLv3 port at `cf4126d17f4520aceb688d8a60daca4a1f0b9e80` supplies 45 native SVG shapes, allowing compositor-native rendering while the original XCursor payload remains available to GTK and XWayland.
- The port's arrow hotspot was `0.203125,0.140625` and link pointer was `0.5,0.25`; the overlay aligns them to the corrected original 64-pixel ratios `12/64,8/64` and `27/64,14/64` respectively.
- 2026-09-22: pixel-level measurement of the rendered SVGs showed the upstream hotspot pins were still off by ~1 source pixel. Arrow visual tip is at (5.4,4.1) on the 32px canvas while the pin declared (6,4); pointer tip is at (13.6,6.1) while the pin declared (13.5,7). The pins were corrected to `0.16875,0.128125` (arrow) and `0.425,0.190625` (pointer), the native `.hlc` payload was rebuilt and reapplied, and the tracked XCursor binaries were patched to the same proportional coordinates (arrow 32px (5,4), 40px (7,5), 48px (8,6), 64px (11,8); pointer 32px (14,6), 40px (17,8), 48px (20,9), 64px (27,12)) covering every arrow-family base (`default`, `copy`, `alias`, `context-menu`, `no-drop`, `progress`) and `pointer`. `check.sh` pins were updated to the new values.
- 2026-09-22 (later): a pointy "Posy-style" arrow variant was prototyped (sharpened tip on the original silhouette, then a classic-proportioned replacement) but the user rejected it — the Future body proportions look deformed with a sharp tip. **Reverted to the upstream rounded arrow**; only the hotspot corrections above remain. Reference notes kept: XCursor image chunks are 9 uint32 fields `(size,type,nominal,version=1,w,h,xhot,yhot,delay=50)` + premultiplied BGRA pixels; PNGs render via `rsvg-convert` at 32/40/48/64 px under nominals 24/30/36/48; same-name `hyprctl setcursor` can serve stale textures — cycle to another theme and back to force a reload; running clients cache their own XCursor theme and need a restart.
- Cursor aliases are symlink-rich directory trees. File-only restore traversal cannot faithfully remove new entries and restore an earlier tree, so tree roots require explicit replacement metadata.

## Decision

Vendor the reviewed upstream XCursor `dist/` payload under `dotfiles/.local/share/icons/Future-cursors` and the pinned native port's SVG working source under `cursor-sources/Future-cyan-hyprcursor`, including GPLv3 provenance. Build the native theme locally with `hyprcursor-util` and merge it into the same installed `Future-cursors` directory so one identifier serves Hyprcursor and XCursor clients. Keep the visually accepted logical size 46 in HyDE, both session environment formats, GSettings, and both user-owned default aliases. Install the combined payload as one backed-up tree and preserve XCursor symlinks. Back up the previous GSettings cursor values for rollback. Keep the documented arrow and pointer hotspot adjustments unless controlled visual testing proves a better coordinate. When patching compiled XCursor binaries, the xhot/yhot little-endian uint32 fields sit at offset 24/28 of each image chunk (chunk header is 36 bytes); patch every representative size and every symlinked base, not only `default`/`pointer`.

## Validation

- Run `./check.sh`, `./install.sh --dry-run --skip-packages`, `git diff --check`, and inspect `git diff`.
- Confirm `hyprctl setcursor Future-cursors 46` succeeds and both GSettings cursor values become `Future-cursors` and `46` through the supported configuration flow.
- Confirm the installed combined tree has 111 XCursor entries with no broken symlinks, 45 native `.hlc` shapes, and matching pinned license/provenance checks.
- Confirm `cursor:enable_hyprcursor` is true and explicitly set after installation.
- Verify the default arrow, link pointer, text beam, every resize direction, small click targets and repeated pointer crossing on both active outputs.
- Start a new login session before concluding that every newly launched XWayland or environment-inheriting client uses the new defaults.

## Exit criteria

Revisit when the monitor scales change, HyDE changes its cursor schema, upstream publishes a reviewed hotspot fix, or a reproducible shape-specific hotspot error survives a fresh login with all selectors agreeing. Any custom hotspot patch must document the affected cursor name, scale, old coordinate, new coordinate and visual acceptance evidence.
