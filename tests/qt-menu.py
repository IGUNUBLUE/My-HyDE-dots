"""Check preservation and idempotence across different theme structures."""
import configparser
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
merge = runpy.run_path(str(root / 'dotfiles/.local/bin/my-hyde-qt-menu'))['merge']
prefs = configparser.ConfigParser(interpolation=None)
prefs.read(root / 'dotfiles/.config/hyde/qt-menu.ini')
for color in ('#ffffff', '#111111'):
    original = ('[%General]\nauthor=upstream\nshadowless_popup=true\n'
                '[GeneralColors]\nwindow.color=' + color + '\n'
                '[MenuItem]\ninterior.element=menuitem\ntext.margin.top=1\n'
                '[MenuItem]\ntext.focus.color=' + color + '\n')
    updated = merge(original, prefs)
    assert merge(updated, prefs) == updated
    assert 'window.color=' + color in updated
    assert 'text.focus.color=' + color in updated
    assert 'interior.element=menuitem' in updated
    assert 'author=upstream' in updated
    result = configparser.ConfigParser(interpolation=None, strict=False)
    result.read_string(updated)
    for section in prefs.sections():
        for key, value in prefs.items(section):
            assert result.get(section, key) == value, (section, key)
print('Qt menu: palette preservation, duplicate sections and idempotence passed.')
