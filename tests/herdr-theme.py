#!/usr/bin/env python3
"""Guard targeted preferences, private-state preservation and focused rollback."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('merge_overlay', ROOT / 'tools/merge-toml-overlay.py')
merge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(merge)


class HerdrTheme(unittest.TestCase):
    def test_merge_preserves_unrelated_arrays_and_snapshots_only_declared_keys(self):
        original = '# user preferences\n[theme]\nauto_switch=false\n[[keys.command]]\nkey="prefix+x"\ncommand="true"\n[ui]\npane_scrollbars=true\n'
        profile = tomllib.loads((ROOT / 'dotfiles/.config/hyde/herdr-theme.toml').read_text())
        result = merge.merge(original, profile)
        data = tomllib.loads(result)
        self.assertEqual(data['keys']['command'][0]['key'], 'prefix+x')
        self.assertTrue(data['ui']['pane_scrollbars'])
        self.assertEqual(merge.merge(result, profile), result)
        selected = merge.select(data, profile)
        self.assertEqual(set(selected), {'theme'})
        self.assertEqual(selected, profile)
        radar = tomllib.loads(merge.merge('[[rules]]\nname="keep"\n', {'follow_appearance': False}))
        self.assertFalse(radar['follow_appearance'])
        self.assertEqual(radar['rules'][0]['name'], 'keep')

    def test_focused_install_restore_and_invalid_second_file(self):
        with tempfile.TemporaryDirectory() as td:
            home, binaries = Path(td) / 'home', Path(td) / 'bin'
            home.mkdir(); binaries.mkdir()
            bootstrap = home / '.local/share/hypr/hyde.lua'
            bootstrap.parent.mkdir(parents=True); bootstrap.touch()
            cfg = home / '.config/herdr/config.toml'
            cfg.parent.mkdir(parents=True)
            original = '[theme]\nauto_switch=false\n[ui]\npane_scrollbars=true\n'
            cfg.write_text(original); cfg.chmod(0o600)
            radar = home / '.config/herdr/plugins/config/hhdebb.herdr-radar/config.toml'
            radar.parent.mkdir(parents=True); radar.write_text('invalid [')
            for name in ('herdr', 'hyde-shell', 'hyprctl', 'systemctl'):
                p = binaries / name
                p.write_text('#!/bin/bash\n' + ('echo "status: running"\n' if name == 'herdr' else 'exit 0\n'))
                p.chmod(0o755)
            env = dict(os.environ, HOME=str(home), PATH=f'{binaries}:/usr/bin:/bin',
                       XDG_CONFIG_HOME=str(home / '.config'), XDG_STATE_HOME=str(home / '.local/state'))
            def run(*args):
                return subprocess.run(args, env=env, capture_output=True, text=True)
            invalid = run(str(ROOT / 'install.sh'), '--herdr-theme-only')
            self.assertNotEqual(invalid.returncode, 0)
            self.assertEqual(cfg.read_text(), original)
            radar.unlink()
            result = run(str(ROOT / 'install.sh'), '--herdr-theme-only')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(cfg.stat().st_mode & 0o777, 0o600)
            self.assertTrue(tomllib.loads(cfg.read_text())['theme']['auto_switch'])
            self.assertFalse(tomllib.loads(radar.read_text())['follow_appearance'])
            backup = next((home / '.local/state/my-hyde-dots/backups').iterdir())
            result = run(str(ROOT / 'restore.sh'), str(backup))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(cfg.read_text(), original)
            self.assertFalse(radar.exists())


if __name__ == '__main__':
    unittest.main()
