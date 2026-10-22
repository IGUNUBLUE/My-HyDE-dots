#!/usr/bin/env python3
"""Exercise the destructive boundary and the focused install/restore in a fake HOME."""
import os
import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys

REPO = Path(__file__).resolve().parents[1]


class NetworkMigration(unittest.TestCase):
    def test_one_status_label_with_both_links_and_escaped_names(self):
        sys.dont_write_bytecode = True
        loader = importlib.machinery.SourceFileLoader('network_status', str(REPO / 'dotfiles/.local/bin/my-hyde-network-status'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        wifi = dict(kind='wifi', name='Lab <&> ' + 'á' * 40, interface='wl-test', signal=75, addresses=[])
        wired = dict(kind='ethernet', name='Office cable', interface='en-test', signal=0, addresses=[])
        result = module.format_status([wired, wifi], 'Office cable')
        self.assertEqual(result['class'], 'wifi')
        self.assertEqual(result['text'].count(''), 1)
        self.assertNotIn('󰈀', result['text'])
        self.assertIn('&lt;&amp;&gt;', result['text'])
        self.assertIn('á' * 40, result['tooltip'])
        self.assertIn('Office cable', result['tooltip'])
        self.assertEqual(module.format_status([wired])['class'], 'ethernet')
        self.assertEqual(module.format_status([])['class'], 'disconnected')

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin',
                        XDG_STATE_HOME=str(self.home / '.local/state'),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        XDG_DATA_HOME=str(self.home / '.local/share'),
                        XDG_CACHE_HOME=str(self.home / '.cache'),
                        CALLS=str(self.root / 'calls'), PLAN='network-manager-applet')
        self.stub('sudo', 'printf "sudo %s\\n" "$*" >> "$CALLS"; exit "${SUDO_RC:-0}"')
        self.stub('pacman', '''case "$*" in
            '-Q networkmanager-dmenu') exit 1 ;;
            '-Q networkmanager'|'-Q rofi') exit 0 ;;
            '-Q nmrs') exit 1 ;;
            '-Q network-manager-applet') echo 'network-manager-applet 1.36.0-2' ;;
            '-R --print --print-format %n network-manager-applet') printf '%s\\n' "$PLAN" ;;
            *) exit 99 ;;
        esac''')
        self.stub('networkmanager_dmenu', 'echo "networkmanager_dmenu 2.7.2"')
        self.stub('rofi', 'echo "Version: 2.0"')
        for cmd in ('hyprctl', 'hyde-shell', 'systemctl', 'pkill'):
            self.stub(cmd, f'printf "{cmd} %s\\n" "$*" >> "$CALLS"')
        entry = self.home / '.local/share/hypr/hyde.lua'
        entry.parent.mkdir(parents=True)
        entry.touch()
        self.live = self.home / '.config/hypr/hyprland.lua'
        self.live.parent.mkdir(parents=True)
        self.live.write_text('-- previous config\n')

    def stub(self, name, body):
        p = self.bin / name
        p.write_text('#!/bin/bash\n' + body + '\n')
        p.chmod(0o755)

    def invoke(self, *args):
        return subprocess.run(args, env=self.env, text=True, capture_output=True)

    def removal(self):
        return self.invoke('bash', '-ec', '''
            source "$1/tools/network.sh"
            dry_run=false; assume_yes=true; backup_dir="$HOME/backup"
            run() { "$@"; }
            remove_legacy_network_applet
        ''', 'test', str(REPO))

    def test_cleanup_is_scoped_and_rollback_restores_nmrs_assets(self):
        legacy = self.home / '.config/nmrs'
        legacy.mkdir(parents=True)
        (legacy / 'style.css').write_text('previous palette')
        (legacy / 'unrelated-preference').write_text('keep')
        launcher = self.home / '.config/rofi/config.rasi'
        launcher.parent.mkdir(parents=True)
        launcher.write_text('previous app launcher')
        result = self.invoke(str(REPO / 'install.sh'), '--network-only', '--skip-packages')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((legacy / 'style.css').exists())
        self.assertEqual((legacy / 'unrelated-preference').read_text(), 'keep')
        self.assertEqual(launcher.read_text(), 'previous app launcher')
        backup = next((self.home / '.local/state/my-hyde-dots/backups').iterdir())
        result = self.invoke(str(REPO / 'restore.sh'), str(backup))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((legacy / 'style.css').read_text(), 'previous palette')
        self.assertEqual((legacy / 'unrelated-preference').read_text(), 'keep')
        self.assertEqual(launcher.read_text(), 'previous app launcher')

    def test_removal_is_nonrecursive_and_records_only_the_legacy_package(self):
        result = self.removal()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'calls').read_text(),
                         'sudo pacman -R --noconfirm network-manager-applet\n')
        self.assertEqual((self.home / 'backup/.network-package-state').read_text(),
                         'network-manager-applet 1.36.0-2\n')

    def test_unexpected_removal_plan_never_calls_sudo(self):
        self.env['PLAN'] = 'network-manager-applet\nnetworkmanager'
        result = self.removal()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'calls').exists())

    def test_nmrs_removal_has_the_same_exact_package_boundary(self):
        self.stub('pacman', '''case "$*" in
            '-Q nmrs') echo 'nmrs 1.6.0-1' ;;
            '-Q network-manager-applet') exit 1 ;;
            '-R --print --print-format %n nmrs') printf '%s\\n' "$PLAN" ;;
            *) exit 99 ;;
        esac''')
        self.env['PLAN'] = 'nmrs\nnetworkmanager'
        self.assertNotEqual(self.removal().returncode, 0)
        self.assertFalse((self.root / 'calls').exists())
        self.env['PLAN'] = 'nmrs'
        result = self.removal()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'calls').read_text(), 'sudo pacman -R --noconfirm nmrs\n')

    def test_broken_replacement_never_removes_applet(self):
        self.stub('networkmanager_dmenu', 'exit 1')
        self.assertNotEqual(self.removal().returncode, 0)
        self.assertFalse((self.root / 'calls').exists())

    def test_failed_package_install_does_not_change_live_configuration(self):
        self.env['SUDO_RC'] = '1'
        result = self.invoke(str(REPO / 'install.sh'), '--network-only', '--yes')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.live.read_text(), '-- previous config\n')
        self.assertNotIn('pacman -R', (self.root / 'calls').read_text())
        self.assertFalse((self.home / '.config/autostart/nm-applet.desktop').exists())

    def test_skip_packages_install_and_restore_only_recorded_files(self):
        result = self.invoke(str(REPO / 'install.sh'), '--network-only', '--skip-packages')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'calls').read_text()
        self.assertNotIn('sudo', calls)
        self.assertNotIn('yay', calls)
        self.assertTrue((self.home / '.local/bin/my-hyde-network').stat().st_mode & 0o111)
        self.assertTrue((self.home / '.local/bin/my-hyde-network-status').stat().st_mode & 0o111)
        self.assertIn('Hidden=true', (self.home / '.config/autostart/nm-applet.desktop').read_text())
        untouched = self.home / 'untouched'
        untouched.write_text('keep')
        backup = next((self.home / '.local/state/my-hyde-dots/backups').iterdir())
        # Package metadata must never be restored as a dotfile in HOME.
        (backup / '.network-package-state').write_text('network-manager-applet 1.36.0-2\n')
        result = self.invoke(str(REPO / 'restore.sh'), str(backup))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.live.read_text(), '-- previous config\n')
        self.assertFalse((self.home / '.config/autostart/nm-applet.desktop').exists())
        self.assertFalse((self.home / '.local/bin/my-hyde-network').exists())
        self.assertFalse((self.home / '.local/bin/my-hyde-network-status').exists())
        self.assertFalse((self.home / '.network-package-state').exists())
        self.assertFalse((self.home / '.local/share/applications/networkmanager_dmenu.desktop').exists())
        self.assertFalse((self.home / '.config/networkmanager-dmenu/config.ini').exists())
        self.assertFalse((self.home / '.config/rofi/network.rasi').exists())
        self.assertEqual(untouched.read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
