#!/usr/bin/env python3
"""Merge or snapshot declared scalar preferences, preserving private settings."""
import json
from pathlib import Path
import re
import sys
import tomllib


def tables(data, prefix=''):
    scalars = {k: v for k, v in data.items() if not isinstance(v, dict)}
    if scalars:
        yield prefix, scalars
    for key, value in data.items():
        if isinstance(value, dict):
            yield from tables(value, f'{prefix}.{key}' if prefix else key)


def merge(text, overlay):
    tomllib.loads(text)
    for section, values in tables(overlay):
        lines = text.splitlines(keepends=True)
        headers = [(i, m.group(1).strip()) for i, line in enumerate(lines)
                   if (m := re.match(r'^\s*\[([^\n]+)\]\s*(?:#.*)?$', line))]
        found = next((n for n, (_, name) in enumerate(headers) if name == section), None)
        if not section:
            start, end = 0, headers[0][0] if headers else len(lines)
        elif found is None:
            text = text.rstrip() + f'\n\n[{section}]\n'
            lines = text.splitlines(keepends=True)
            start = end = len(lines)
        else:
            start = headers[found][0] + 1
            end = headers[found + 1][0] if found + 1 < len(headers) else len(lines)
        for key, value in values.items():
            replacement = f'{key} = {json.dumps(value, ensure_ascii=False)}\n'
            matches = [i for i in range(start, end) if re.match(rf'^\s*{re.escape(key)}\s*=', lines[i])]
            if matches:
                lines[matches[0]] = replacement
            else:
                lines.insert(end, replacement)
                end += 1
        text = ''.join(lines)
    result = tomllib.loads(text)
    for section, values in tables(overlay):
        actual = result
        for part in section.split('.') if section else []:
            actual = actual[part]
        if any(actual.get(key) != value for key, value in values.items()):
            raise ValueError(f'Overlay did not apply at {section or "root"}')
    return text.lstrip('\n')


def select(actual, declared):
    result = {}
    for key, value in declared.items():
        if key not in actual:
            continue
        chosen = select(actual[key], value) if isinstance(value, dict) else actual[key]
        if not isinstance(chosen, dict) or chosen:
            result[key] = chosen
    return result


if __name__ == '__main__':
    args = sys.argv[1:]
    snapshot = args[0] == '--snapshot'
    source, profile, target = map(Path, args[1:] if snapshot else args)
    if snapshot and not source.exists():
        sys.exit(0)
    text = source.read_text() if source.exists() else ''
    declared = tomllib.loads(profile.read_text())
    result = merge('', select(tomllib.loads(text), declared)) if snapshot else merge(text, declared)
    target.write_text(result)
