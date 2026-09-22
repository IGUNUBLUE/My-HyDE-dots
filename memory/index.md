# Memory index

Read active and monitoring entries relevant to a component before modifying it.

| Status | Scope | Memory | Summary |
| --- | --- | --- | --- |
| active | Hypridle, Hyprlock, NVIDIA, displays | [Hyprlock input stall mitigation](incidents/2026-09-02-hyprlock-input-stall.md) | Keep automatic lock, DPMS-off and suspend disabled until a controlled dual-monitor unlock test succeeds on a fixed version. |
| active | Waybar, displays, fractional scaling | [Stable Waybar height](decisions/2026-09-03-waybar-stable-height.md) | Use the historical 22-pixel bar with scoped GTK minimum heights; require real pointer-crossing acceptance and retain 26 pixels as rollback. |
| active | Cursor, HyDE, GTK, XWayland, displays | [Future cursor consistency](decisions/2026-09-09-future-cursor-hotspots.md) | Build native Hyprcursor and XCursor fallback under one Future-cursors name at accepted size 46; preserve reviewed hotspots and mixed-scale acceptance. |
| superseded | Hyprland, Waybar, Rofi, Kitty, btop, Wallbash, NVIDIA | [Glass panels with opaque windows](decisions/2026-09-11-glass-panels-opaque-windows.md) | Historical glass profile; replaced after diffuse blur caused eye strain. |
| active | Hyprland, Waybar, Rofi, Kitty, Swaync, NVIDIA | [Solid-first eye comfort profile](decisions/2026-09-11-solid-first-eye-comfort.md) | Fully solid surfaces except Kitty 0.97; per-theme WCAG AA state colors; compositor and layer blur disabled. |
| active | Qt, Kvantum, Wallbash | [Global Qt menus](decisions/2026-09-04-global-qt-menus.md) | Apply qt-menu.ini through the documented Wallbash callback across themes. |
| active | fontconfig, HyDE fonts, displays | [Sharp LCD font baseline](decisions/2026-09-15-font-sharpness.md) | Keep user-owned hintslight + rgb + lcddefault baseline and matching HyDE slight hinting; system /etc/fonts stays untouched. |
| active | Swaync, Wallbash, light themes | [Readable swaync text on light themes](decisions/2026-09-17-swaync-light-theme-text.md) | Upstream swaync.dcol hardcodes white text; re-map it to theme colors in user-style.css until upstream derives text color from the palette. |
| active | LAGC themes, accents, GTK/icons, cursor | [Minimal accent discipline and theme cursor declaration](decisions/2026-09-19-minimal-accent-discipline.md) | One interactive accent family, ember for attention only, lifted cobalt on dark, neutral adw-gtk3 + Fluent-teal; declare $CURSOR_THEME in hypr.theme or theme.switch regresses the aliases. |
| active | HyDE themes, fonts, theme switching | [LAGC Calm theme pair](decisions/2026-09-21-lagc-calm-themes.md) | Warm low-glare Dark/Light pair with static theme.dcol palettes (fixes wallpaper-derived color mismatch), Atkinson Hyperlegible as global UI font, per-app reload coverage after theme switches. |
| active | VSCodium, editor themes | [VSCodium LAGC Calm themes](decisions/2026-09-22-vscodium-calm-themes.md) | VS Code-compatible lagc-calm extension packaged via codium --install-extension; Kiro and Zed support removed. |
