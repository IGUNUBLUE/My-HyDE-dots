#!/usr/bin/env python3
"""Merge the overlay's file-manager defaults without copying private associations."""
import configparser
from pathlib import Path
import re
import sys

source, preferences, output = map(Path, sys.argv[1:])
desired = configparser.ConfigParser(interpolation=None)
desired.read(preferences)
lines = source.read_text().splitlines(keepends=True) if source.exists() else []
retired = {"org.gnome.Nautilus.desktop", "org.gnome.FileRoller.desktop"}
for section in desired.sections():
    header = f"[{section}]"
    start = next((i for i, line in enumerate(lines) if line.strip() == header), None)
    if start is None:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        lines.extend(["\n", header + "\n"])
        start = len(lines) - 1
    end = next((i for i in range(start + 1, len(lines))
                if lines[i].strip().startswith("[")), len(lines))
    for key, value in desired[section].items():
        index = next((i for i in range(start + 1, end)
                      if re.match(r"^\s*" + re.escape(key) + r"\s*=", lines[i])), None)
        if section == "Added Associations" and index is not None:
            existing = lines[index].split("=", 1)[1].strip().split(";")
            value = ";".join(dict.fromkeys(
                value.strip(";").split(";") +
                [item for item in existing if item and item not in retired])) + ";"
        replacement = f"{key}={value}\n"
        if index is None:
            if end and not lines[end - 1].endswith("\n"):
                lines[end - 1] += "\n"
            lines.insert(end, replacement)
            end += 1
        else:
            lines[index] = replacement
output.write_text("".join(lines))
