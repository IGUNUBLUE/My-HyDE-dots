#!/usr/bin/env python3
"""Run the supported lifecycle in an isolated HOME, mocking desktop boundaries."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='my-hyde-lifecycle-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.bin = self.root / 'bin'
        self.home.mkdir()
        self.bin.mkdir()
        # Do not inherit the owner's client paths or desktop connection.
        self.env = dict(PATH=f'{self.bin}:/usr/bin:/bin', HOME=str(self.home),
                        TMPDIR=os.environ.get('TMPDIR', '/tmp'),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        XDG_DATA_HOME=str(self.home / '.local/share'),
                        XDG_CACHE_HOME=str(self.home / '.cache'),
                        XDG_STATE_HOME=str(self.home / '.local/state'),
                        XDG_RUNTIME_DIR=str(self.root / 'run'),
                        CALLS=str(self.root / 'calls'),
                        PACKAGE_STATE=str(self.root / 'swaync-installed'),
                        NO_SESSION='0')
        (self.root / 'swaync-installed').touch()
        self.stub('sudo', '[[ $1 != pacman ]] || { shift; exec pacman "$@"; }; exit 99')
        self.stub('pacman', '''case "$1" in
            -Q) [[ $2 != swaync || -f $PACKAGE_STATE ]] ;;
            -S) touch "$PACKAGE_STATE" ;;
            *) exit 99 ;;
        esac''')
        self.stub('hyprctl', '[[ $NO_SESSION == 0 ]]')
        for name in ('hyde-shell', 'networkmanager_dmenu', 'rofi', 'systemctl',
                     'gsettings', 'dbus-update-activation-environment', 'codium',
                     'update-desktop-database', 'fc-cache', 'pkill'):
            self.stub(name, 'exit 0')
        self.stub('curl', 'exit 22')
        self.stub('magick', 'printf generated > "${@: -1}"')
        self.write('.local/share/hypr/hyde.lua', '-- installed by official HyDE\n')
        self.write('.local/share/wallbash/theme/kvantum/kvconfig.dcol',
                   '$HOME/.config/Kvantum/wallbash/wallbash.kvconfig\n[General]\n')
        self.write('.config/Kvantum/wallbash/wallbash.kvconfig', '[General]\n')
        self.write('.config/hypr/hyprland.lua', '-- before overlay\n')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\nprintf "%s %s\\n" "${0##*/}" "$*" >> "$CALLS"\n' + body + '\n')
        path.chmod(0o755)

    def write(self, relative, content):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def invoke(self, script='install.sh', *args):
        return subprocess.run([str(REPO / script), *args], env=self.env,
                              text=True, capture_output=True)

    def calls(self):
        path = self.root / 'calls'
        return path.read_text() if path.exists() else ''

    def test_packages_install_the_notification_daemon(self):
        (self.root / 'swaync-installed').unlink()
        result = self.invoke('install.sh', '--yes', '--only', 'packages')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / 'swaync-installed').exists(), self.calls())
        self.assertIn('pacman -S --needed --noconfirm swaync', self.calls())

    def test_applying_profile_replaces_the_running_dunst_daemon(self):
        self.env['DAEMON_STATE'] = str(self.root / 'notification-daemon')
        (self.root / 'notification-daemon').write_text('dunst')
        self.stub('systemctl', '''case "$*" in
            *'stop '*'hyde-Hyprland-notifications.service'*) rm -f "$DAEMON_STATE" ;;
            *'restart swaync.service'*)
                [[ ! -f $DAEMON_STATE ]] || exit 1
                printf swaync > "$DAEMON_STATE" ;;
        esac''')
        result = self.invoke('install.sh', '--yes', '--skip-packages', '--only', 'config,apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'notification-daemon').read_text(), 'swaync')

    def test_missing_swaync_refuses_config_before_writing(self):
        (self.root / 'swaync-installed').unlink()
        before = (self.home / '.config/hypr/hyprland.lua').read_text()
        result = self.invoke('install.sh', '--yes', '--skip-packages', '--only', 'config')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('swaync', result.stderr)
        self.assertEqual((self.home / '.config/hypr/hyprland.lua').read_text(), before)
        self.assertFalse((self.home / '.local/state/my-hyde-dots').exists())

    def test_live_install_without_session_refuses_before_packages_or_files(self):
        self.env['NO_SESSION'] = '1'
        self.env['HYPRLAND_INSTANCE_SIGNATURE'] = 'stale-session'
        (self.root / 'swaync-installed').unlink()
        before = (self.home / '.config/hypr/hyprland.lua').read_text()
        result = self.invoke('install.sh', '--yes', '--only', 'packages,config,apply')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Hyprland', result.stderr)
        self.assertEqual((self.home / '.config/hypr/hyprland.lua').read_text(), before)
        self.assertFalse((self.home / '.local/state/my-hyde-dots').exists())
        self.assertNotIn('sudo ', self.calls())

    def test_network_only_without_session_preserves_files(self):
        self.env['NO_SESSION'] = '1'
        before = (self.home / '.config/hypr/hyprland.lua').read_text()
        result = self.invoke('install.sh', '--network-only', '--skip-packages')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / '.config/hypr/hyprland.lua').read_text(), before)

    def test_file_only_and_dry_run_work_without_session(self):
        self.env['NO_SESSION'] = '1'
        for args in (('--dry-run', '--only', 'config,apply'), ('--only', 'config')):
            result = self.invoke('install.sh', '--yes', '--skip-packages', *args)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hyprctl ', self.calls())

    def test_all_themes_have_wallpapers_without_nextcloud(self):
        # Use ImageMagick itself for the new Tech fallback, not a placeholder.
        self.stub('magick', '''if [[ ${@: -1} == *lagc-tech-* ]]; then
            exec /usr/bin/magick "$@"
        fi
        touch -- "${@: -1}"''')
        result = self.invoke('install.sh', '--yes', '--only', 'themes')
        self.assertEqual(result.returncode, 0, result.stderr)
        for theme in ('LAGC Tech Dark', 'LAGC Tech Light', 'LAGC Calm Dark', 'LAGC Calm Light'):
            link = self.home / '.config/hyde/themes' / theme / 'wall.set'
            self.assertTrue(link.is_symlink(), theme)
            self.assertTrue(link.exists(), theme)
            if 'Tech' in theme:
                image = subprocess.run(['/usr/bin/magick', 'identify', '-format', '%m %wx%h', str(link)],
                                       capture_output=True, text=True)
                self.assertEqual(image.returncode, 0, image.stderr)
                self.assertEqual(image.stdout, 'PNG 1920x1080')

    def test_offline_wallpaper_reinstall_restores_previous_image(self):
        previous = self.write('.config/hyde/themes/LAGC Calm Dark/wallpapers/lagc-calm-dark.png',
                              'previous wallpaper')
        unrelated = self.write('.config/hyde/themes/LAGC Calm Dark/wallpapers/personal.txt', 'keep')
        result = self.invoke('install.sh', '--yes', '--only', 'themes')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(previous.read_text(), 'generated')
        backup = next((self.home / '.local/state/my-hyde-dots/backups').iterdir())
        result = self.invoke('restore.sh', str(backup))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(previous.read_text(), 'previous wallpaper')
        self.assertEqual(unrelated.read_text(), 'keep')

    def test_restore_recovers_regular_and_dangling_symlinks(self):
        target = self.home / '.config/satty/config.toml'
        target.parent.mkdir(parents=True)
        original = self.write('personal-satty.toml', '[general]\ninitial-tool = "arrow"\n')
        for destination in (original, self.home / 'missing-satty.toml'):
            with self.subTest(dangling=not destination.exists()):
                if target.exists() or target.is_symlink():
                    target.unlink()
                target.symlink_to(destination)
                result = self.invoke('install.sh', '--satty-only')
                self.assertEqual(result.returncode, 0, result.stderr)
                backup = sorted((self.home / '.local/state/my-hyde-dots/backups').iterdir())[-1]
                result = self.invoke('restore.sh', str(backup))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(target.is_symlink())
                self.assertEqual(target.readlink(), destination)
                self.assertEqual(original.read_text(), '[general]\ninitial-tool = "arrow"\n')
                # Keep the two independent installations out of timestamp collisions.
                shutil.rmtree(backup)


if __name__ == '__main__':
    unittest.main()
