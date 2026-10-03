"""Behavioral tests for the Wallbash always/ hook scripts.

Each script runs in a throwaway XDG tree with fake gsettings/fc-match commands
on PATH, so nothing on the real desktop is read or written.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "dotfiles/.config/hyde/wallbash/scripts"
RHUN_THEMES = ROOT / "dotfiles/.config/rhun/themes"
FAILURES: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        FAILURES.append(message)


class Sandbox:
    def __init__(self) -> None:
        self.root = Path(tempfile.mkdtemp(prefix="hyde-hook-test-"))
        self.config = self.root / "config"
        self.data = self.root / "data"
        self.state = self.root / "state"
        self.bin = self.root / "bin"
        self.log = self.root / "calls.log"
        for path in (self.config, self.data, self.state, self.bin):
            path.mkdir(parents=True)
        self.log.touch()
        # gsettings stub: records every call, answers `get gtk-theme`.
        self.fake("gsettings", f"""#!/usr/bin/env bash
echo "gsettings $*" >> "{self.log}"
[[ $1 == get && $3 == gtk-theme ]] && echo "'Wallbash-Gtk'"
exit 0
""")

    def fake(self, name: str, body: str) -> None:
        path = self.bin / name
        path.write_text(body)
        path.chmod(0o755)

    def env(self, **extra: str) -> dict[str, str]:
        env = {
            "HOME": str(self.root),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "XDG_CONFIG_HOME": str(self.config),
            "XDG_DATA_HOME": str(self.data),
            "XDG_STATE_HOME": str(self.state),
            "MY_HYDE_GTK_SETTLE": "0",
            "MY_HYDE_GTK_GAP": "0",
        }
        env.update(extra)
        return env

    def run(self, script: str, **extra: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["bash", str(SCRIPTS / script)], env=self.env(**extra),
            capture_output=True, text=True, timeout=30,
        )

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines()

    def close(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)


# --- my-hyde-gtk-dark-mode.sh -------------------------------------------------

def gtk_sandbox(mode: str, prefer_dark: str | None) -> Sandbox:
    box = Sandbox()
    gtk3 = box.config / "gtk-3.0"
    gtk3.mkdir()
    (gtk3 / ".wallbash-dark-mode").write_text(mode + "\n")
    if prefer_dark is not None:
        (gtk3 / "settings.ini").write_text(
            "[Settings]\ngtk-theme-name=Wallbash-Gtk\n"
            f"gtk-application-prefer-dark-theme={prefer_dark}\n")
    for version in ("gtk-3.0", "gtk-4.0"):
        theme = box.data / "themes/Wallbash-Gtk" / version
        theme.mkdir(parents=True)
        (theme / "gtk.css").write_text("@define-color theme_bg_color #2B2522;\n")
        (theme / "gtk-dark.css").write_text("@define-color theme_bg_color #2B2522;\n")
    return box


def reemits(calls: list[str]) -> bool:
    sets = [c.replace("'", "") for c in calls
            if c.startswith("gsettings set org.gnome.desktop.interface gtk-theme")]
    return len(sets) >= 2 and sets[-1].endswith("Wallbash-Gtk")


def test_gtk_same_mode_switch_still_refreshes_browsers() -> None:
    # Regression: Calm Dark -> Tech Dark keeps prefer-dark=1, yet Wallbash-Gtk's
    # css changed in place; GTK-mode Chrome/Brave/Firefox only re-read it when
    # gtk-theme is re-emitted.
    box = gtk_sandbox("dark", "1")
    try:
        result = box.run("my-hyde-gtk-dark-mode.sh")
        check(result.returncode == 0, f"gtk hook failed on same-mode switch: {result.stderr}")
        check(reemits(box.calls()), "gtk hook must re-emit gtk-theme on a same-mode switch "
              f"so GTK-mode browsers reload Wallbash-Gtk; calls={box.calls()}")
        ini = (box.config / "gtk-3.0/settings.ini").read_text()
        check("gtk-application-prefer-dark-theme=1" in ini, "same-mode switch must keep prefer-dark=1")
    finally:
        box.close()


def test_gtk_mode_flip_writes_flag_and_refreshes() -> None:
    for mode, before, after in (("dark", "0", "1"), ("light", "1", "0")):
        box = gtk_sandbox(mode, before)
        try:
            box.run("my-hyde-gtk-dark-mode.sh")
            ini = (box.config / "gtk-3.0/settings.ini").read_text()
            check(f"gtk-application-prefer-dark-theme={after}" in ini,
                  f"{mode}: prefer-dark must become {after}, got:\n{ini}")
            check(reemits(box.calls()), f"{mode}: mode flip must re-emit gtk-theme")
        finally:
            box.close()


def test_gtk_creates_missing_ini() -> None:
    box = gtk_sandbox("light", None)
    try:
        box.run("my-hyde-gtk-dark-mode.sh")
        ini = (box.config / "gtk-3.0/settings.ini").read_text()
        check(ini.startswith("[Settings]") and "gtk-application-prefer-dark-theme=0" in ini,
              f"missing settings.ini must be created with [Settings] and the flag, got:\n{ini}")
    finally:
        box.close()


def test_gtk_waits_for_dark_css_copy() -> None:
    # gtk3.dcol/gtk4.dcol copy gtk.css to gtk-dark.css in the background; a
    # re-emit before that copy lands makes dark-variant clients load stale css.
    box = gtk_sandbox("dark", "1")
    try:
        dark = box.data / "themes/Wallbash-Gtk/gtk-3.0/gtk-dark.css"
        dark.write_text("@define-color theme_bg_color #0C1C28;\n")  # stale copy
        box.fake("gsettings", f"""#!/usr/bin/env bash
cmp -s '{dark.with_name("gtk.css")}' '{dark}' && state=fresh || state=stale
echo "gsettings $* css=$state" >> "{box.log}"
[[ $1 == get && $3 == gtk-theme ]] && echo "'Wallbash-Gtk'"
exit 0
""")
        late = subprocess.Popen(["bash", "-c", f"sleep 0.6; cp '{dark.with_name('gtk.css')}' '{dark}'"])
        result = box.run("my-hyde-gtk-dark-mode.sh", MY_HYDE_GTK_SETTLE="5")
        late.wait()
        check(result.returncode == 0, f"gtk hook failed while waiting for css: {result.stderr}")
        sets = [c for c in box.calls() if c.startswith("gsettings set")]
        check(bool(sets) and all(c.endswith("css=fresh") for c in sets),
              f"gtk hook re-emitted before gtk-dark.css was refreshed: {sets}")
    finally:
        box.close()


def test_gtk_placeholder_renders_the_same_theme() -> None:
    # Firefox can miss the second of two quick gtk-theme changes and stay on the
    # placeholder; with adw-gtk3 as placeholder it then showed a grey #2E2E32
    # toolbar. The placeholder must therefore be an alias of the real theme.
    box = gtk_sandbox("light", "0")
    try:
        box.run("my-hyde-gtk-dark-mode.sh")
        sets = [c.split()[-1].strip("'") for c in box.calls()
                if c.startswith("gsettings set org.gnome.desktop.interface gtk-theme")]
        check(len(sets) == 2 and sets[1] == "Wallbash-Gtk", f"unexpected re-emit sequence: {sets}")
        if sets:
            alias = box.data / "themes" / sets[0]
            real = box.data / "themes/Wallbash-Gtk"
            check(sets[0] != "Wallbash-Gtk" and alias.resolve() == real.resolve(),
                  f"placeholder {sets[0]!r} must be an alias of Wallbash-Gtk, resolves to {alias.resolve()}")
    finally:
        box.close()


def test_gtk_ignores_unknown_mode() -> None:
    box = gtk_sandbox("sepia", "1")
    try:
        result = box.run("my-hyde-gtk-dark-mode.sh")
        check(result.returncode == 0 and not any("set" in c for c in box.calls()),
              "unknown wallbash mode must be a no-op")
    finally:
        box.close()


# --- my-hyde-rhun-theme.sh ---------------------------------------------------

RHUN_CONFIG = """# rhun configuration.
[ui]
theme = gruvbox-dark
scale = 1.0
font =
[editor]
font_size = 14
font =
[terminal]
shell = /usr/bin/zsh
"""


def rhun_sandbox(mode: str, config: str | None = RHUN_CONFIG) -> Sandbox:
    box = Sandbox()
    rhun = box.config / "rhun"
    (rhun / "themes").mkdir(parents=True)
    for theme in RHUN_THEMES.glob("*.theme"):
        shutil.copy(theme, rhun / "themes")
    (rhun / ".wallbash-mode").write_text(mode + "\n")
    if config is not None:
        (rhun / "config").write_text(config)
    # No fontconfig answers: fonts must be left alone.
    box.fake("fc-match", "#!/usr/bin/env bash\nexit 1\n")
    return box


def rhun_value(box: Sandbox, section: str, key: str) -> str | None:
    current = None
    for line in (box.config / "rhun/config").read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            current = stripped.strip("[]")
        elif current == section and "=" in stripped and stripped.split("=", 1)[0].strip() == key:
            return stripped.split("=", 1)[1].strip()
    return None


def test_rhun_follows_every_lagc_theme() -> None:
    for name, slug, mode in (("LAGC Calm Dark", "lagc-calm-dark", "dark"),
                             ("LAGC Calm Light", "lagc-calm-light", "light"),
                             ("LAGC Tech Dark", "lagc-tech-dark", "dark"),
                             ("LAGC Tech Light", "lagc-tech-light", "light")):
        box = rhun_sandbox(mode)
        try:
            box.run("my-hyde-rhun-theme.sh", HYDE_THEME=name)
            check(rhun_value(box, "ui", "theme") == slug, f"rhun must select {slug} for {name}")
            text = (box.config / "rhun/config").read_text()
            for keep in ("scale = 1.0", "font_size = 14", "shell = /usr/bin/zsh", "# rhun configuration."):
                check(keep in text, f"rhun hook dropped '{keep}' for {name}")
        finally:
            box.close()


def test_rhun_non_lagc_falls_back_to_calm_by_mode() -> None:
    for mode in ("dark", "light"):
        box = rhun_sandbox(mode)
        try:
            box.run("my-hyde-rhun-theme.sh", HYDE_THEME="Catppuccin Latte")
            check(rhun_value(box, "ui", "theme") == f"lagc-calm-{mode}",
                  f"non-LAGC {mode} theme must fall back to lagc-calm-{mode}")
        finally:
            box.close()


def test_rhun_never_selects_missing_theme() -> None:
    box = rhun_sandbox("light")
    try:
        (box.config / "rhun/themes/lagc-tech-light.theme").unlink()
        box.run("my-hyde-rhun-theme.sh", HYDE_THEME="LAGC Tech Light")
        check(rhun_value(box, "ui", "theme") == "gruvbox-dark", "missing theme must leave rhun untouched")
    finally:
        box.close()


def test_rhun_is_idempotent() -> None:
    box = rhun_sandbox("dark")
    try:
        box.run("my-hyde-rhun-theme.sh", HYDE_THEME="LAGC Calm Dark")
        config = box.config / "rhun/config"
        first = config.stat().st_mtime_ns
        box.run("my-hyde-rhun-theme.sh", HYDE_THEME="LAGC Calm Dark")
        check(config.stat().st_mtime_ns == first, "unchanged rhun config must not be rewritten")
    finally:
        box.close()


def test_rhun_creates_config_and_ui_section() -> None:
    box = rhun_sandbox("dark", config=None)
    try:
        box.run("my-hyde-rhun-theme.sh", HYDE_THEME="LAGC Tech Dark")
        check(rhun_value(box, "ui", "theme") == "lagc-tech-dark", "rhun hook must create a config")
    finally:
        box.close()
    box = rhun_sandbox("dark", config="[editor]\nfont_size = 15\n")
    try:
        box.run("my-hyde-rhun-theme.sh", HYDE_THEME="LAGC Tech Dark")
        check(rhun_value(box, "ui", "theme") == "lagc-tech-dark", "rhun hook must add a missing [ui]")
        check(rhun_value(box, "editor", "font_size") == "15", "rhun hook must keep [editor]")
    finally:
        box.close()


def test_rhun_fonts_follow_hyde_and_reject_bad_matches() -> None:
    box = rhun_sandbox("dark")
    try:
        font = box.root / "Good-Mono.ttf"
        # Minimal TrueType header with glyf/loca/cmap table records.
        import struct
        tables = [b"cmap", b"glyf", b"loca"]
        data = struct.pack(">IHHHH", 0x00010000, len(tables), 0, 0, 0)
        for i, tag in enumerate(tables):
            data += struct.pack(">4sIII", tag, 0, 12 + 16 * len(tables), 0)
        font.write_bytes(data)
        (box.config / "hyde").mkdir()
        (box.config / "hyde/config.toml").write_text(
            '[desktop.ui]\nfont = "Good Sans"\nmonospace_font = "Good Mono"\n')
        box.fake("fc-match", f"""#!/usr/bin/env bash
case "${{@: -1}}" in
  "Good Mono") printf 'Good Mono\\t{font}\\t0\\tTrueType\\n' ;;
  *) printf 'DejaVu Sans\\t/usr/share/fonts/DejaVuSans.ttf\\t0\\tTrueType\\n' ;;
esac
""")
        box.run("my-hyde-rhun-theme.sh", HYDE_THEME="LAGC Calm Dark")
        check(rhun_value(box, "editor", "font") == str(font), "editor font must follow HyDE monospace_font")
        check(rhun_value(box, "ui", "font") in ("", None),
              "a fontconfig fallback to another family must not be written as the UI font")
    finally:
        box.close()


# --- my-hyde-waybar-guard.sh ------------------------------------------------

def guard_sandbox(states: list[int], monitors: int = 2, active: bool = True) -> Sandbox:
    """Fake hyprctl answering `layers` with the next number of waybar bars."""
    box = Sandbox()
    queue = box.root / "bars.queue"
    queue.write_text("\n".join(str(s) for s in states) + "\n")
    box.fake("hyprctl", f"""#!/usr/bin/env bash
case "$1" in
  monitors) python3 -c 'import json;print(json.dumps([{{"name":"M%d"%i}} for i in range({monitors})]))' ;;
  layers)
    n=$(head -n 1 "{queue}"); [[ $(wc -l < "{queue}") -gt 1 ]] && sed -i 1d "{queue}"
    python3 -c 'import json,sys
n=int(sys.argv[1])
print(json.dumps({{"M%d"%i:{{"levels":{{"2":[{{"namespace":"waybar"}}] if i<n else []}}}} for i in range({monitors})}}))' "$n" ;;
esac
""")
    box.fake("systemctl", f"""#!/usr/bin/env bash
echo "systemctl $*" >> "{box.log}"
[[ $* == *is-active* ]] && exit {0 if active else 3}
exit 0
""")
    return box


def guard_run(box: Sandbox) -> subprocess.CompletedProcess:
    return box.run("my-hyde-waybar-guard.sh", MY_HYDE_WAYBAR_GUARD_DELAY="0",
                   MY_HYDE_WAYBAR_GUARD_WINDOW="6", MY_HYDE_WAYBAR_GUARD_GRACE="3",
                   MY_HYDE_WAYBAR_GUARD_INTERVAL="0.05", XDG_RUNTIME_DIR=str(box.root))


def restarted(box: Sandbox) -> bool:
    return any("restart hyde-Hyprland-bar.service" in c for c in box.calls())


def test_guard_restarts_waybar_that_lost_its_bars() -> None:
    # Waybar 0.15 can hang inside a SIGUSR2 reload: process alive, no bars.
    box = guard_sandbox([2, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    try:
        result = guard_run(box)
        check(result.returncode == 0, f"guard failed: {result.stderr}")
        check(restarted(box), f"guard must restart Waybar after its bars vanish: {box.calls()}")
    finally:
        box.close()


def test_guard_tolerates_a_normal_reload_gap() -> None:
    # A healthy reload unmaps the bars briefly; that must not trigger a restart.
    box = guard_sandbox([2, 0, 0, 2, 2, 2, 2, 2, 2, 2])
    try:
        guard_run(box)
        check(not restarted(box), f"guard restarted a Waybar that recovered by itself: {box.calls()}")
    finally:
        box.close()


def test_guard_needs_a_bar_on_every_monitor() -> None:
    box = guard_sandbox([1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
    try:
        guard_run(box)
        check(restarted(box), "a bar missing on one monitor must trigger a restart")
    finally:
        box.close()


def test_guard_leaves_a_stopped_waybar_alone() -> None:
    box = guard_sandbox([0] * 10, active=False)
    try:
        guard_run(box)
        check(not restarted(box), "guard must not start a Waybar the user stopped")
    finally:
        box.close()


def test_guard_restarts_at_most_once() -> None:
    box = guard_sandbox([0] * 40)
    try:
        guard_run(box)
        count = sum("restart hyde-Hyprland-bar.service" in c for c in box.calls())
        check(count == 1, f"guard must restart Waybar once per run, not loop: {count}")
    finally:
        box.close()


if __name__ == "__main__":
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
    if FAILURES:
        for failure in FAILURES:
            print("FAIL:", failure)
        raise SystemExit(1)
    print(f"Hook scripts: {len(tests)} behavioral tests passed.")
