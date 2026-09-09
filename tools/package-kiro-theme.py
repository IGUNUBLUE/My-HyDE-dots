#!/usr/bin/env python3
"""Validate and package the portable LAGC Tech Kiro IDE theme extension."""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as element_tree
import zipfile
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
EXTENSION_ROOT = REPOSITORY_ROOT / "dotfiles/.local/share/kiro/themes/lagc-tech"
PACKAGE_NAME = "igunublue.lagc-tech-themes-0.1.1.vsix"
THEMES = {
    "LAGC Tech Dark": ("dark", "themes/lagc-tech-dark-color-theme.json"),
    "LAGC Tech Light": ("light", "themes/lagc-tech-light-color-theme.json"),
}
HEX_COLOR = re.compile(r"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?$")


def load_json(path: Path) -> dict:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Invalid JSON in {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"Expected an object in {path}")
    return value


def validate_color(value: object, context: str) -> None:
    if isinstance(value, str) and HEX_COLOR.fullmatch(value):
        return
    raise ValueError(f"Expected a hexadecimal color in {context}: {value!r}")


def validate_theme(path: Path, expected_name: str, expected_type: str) -> None:
    theme = load_json(path)
    if theme.get("name") != expected_name:
        raise ValueError(f"Unexpected theme name in {path}: {theme.get('name')!r}")
    if theme.get("type") != expected_type:
        raise ValueError(f"Unexpected theme type in {path}: {theme.get('type')!r}")
    if theme.get("semanticHighlighting") is not True:
        raise ValueError(f"Semantic highlighting must be enabled in {path}")

    colors = theme.get("colors")
    if not isinstance(colors, dict) or not colors:
        raise ValueError(f"Theme colors are missing in {path}")
    for color_id, value in colors.items():
        validate_color(value, f"{path}:{color_id}")

    structural_borders = (
        "activityBar.border",
        "sideBar.border",
        "auxiliaryBar.border",
        "editorGroup.border",
        "editorGroupHeader.tabsBorder",
        "editorGroupHeader.border",
        "tab.border",
        "panel.border",
        "panelTitle.border",
        "panelSection.border",
        "terminal.border",
    )
    for color_id in structural_borders:
        if color_id not in colors:
            raise ValueError(f"Structural divider color is missing in {path}: {color_id}")

    token_colors = theme.get("tokenColors")
    if not isinstance(token_colors, list) or not token_colors:
        raise ValueError(f"Token colors are missing in {path}")
    semantic_colors = theme.get("semanticTokenColors")
    if not isinstance(semantic_colors, dict) or not semantic_colors:
        raise ValueError(f"Semantic token colors are missing in {path}")
    for token_id, value in semantic_colors.items():
        validate_color(value, f"{path}:{token_id}")


def validate_extension(source: Path) -> tuple[dict, list[Path]]:
    package_path = source / "package.json"
    readme_path = source / "README.md"
    package = load_json(package_path)
    expected_package = {
        "name": "lagc-tech-themes",
        "displayName": "LAGC Tech Themes",
        "publisher": "igunublue",
        "version": "0.1.1",
    }
    for key, expected in expected_package.items():
        if package.get(key) != expected:
            raise ValueError(f"Unexpected package {key}: {package.get(key)!r}")
    if not readme_path.is_file():
        raise ValueError(f"Missing extension README: {readme_path}")

    contributed = package.get("contributes", {}).get("themes")
    if not isinstance(contributed, list) or len(contributed) != len(THEMES):
        raise ValueError("The extension must contribute exactly the two LAGC themes")

    theme_paths: list[Path] = []
    seen_labels: set[str] = set()
    for entry in contributed:
        if not isinstance(entry, dict):
            raise ValueError("Theme contribution must be an object")
        label = entry.get("label")
        if label not in THEMES:
            raise ValueError(f"Unexpected theme contribution: {label!r}")
        expected_type, expected_path = THEMES[label]
        if entry.get("uiTheme") != ("vs-dark" if expected_type == "dark" else "vs"):
            raise ValueError(f"Unexpected UI theme kind for {label}")
        if entry.get("path") != f"./{expected_path}":
            raise ValueError(f"Unexpected theme path for {label}")
        theme_path = source / expected_path
        validate_theme(theme_path, label, expected_type)
        theme_paths.append(theme_path)
        seen_labels.add(label)
    if seen_labels != THEMES.keys():
        raise ValueError("Both LAGC theme labels must be present")
    return package, theme_paths


def content_types() -> bytes:
    types = element_tree.Element("Types", xmlns="http://schemas.openxmlformats.org/package/2006/content-types")
    for extension, content_type in (
        ("json", "application/json"),
        ("md", "text/markdown"),
        ("xml", "text/xml"),
    ):
        element_tree.SubElement(types, "Default", Extension=extension, ContentType=content_type)
    return element_tree.tostring(types, encoding="utf-8", xml_declaration=True)


def vsix_manifest(package: dict) -> bytes:
    manifest = element_tree.Element(
        "PackageManifest",
        Version="2.0.0",
        xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011",
    )
    metadata = element_tree.SubElement(manifest, "Metadata")
    element_tree.SubElement(
        metadata,
        "Identity",
        Language="en-US",
        Id=package["name"],
        Version=package["version"],
        Publisher=package["publisher"],
    )
    element_tree.SubElement(metadata, "DisplayName").text = package["displayName"]
    element_tree.SubElement(metadata, "Description").text = package["description"]
    element_tree.SubElement(metadata, "Categories").text = "Themes"
    installation = element_tree.SubElement(manifest, "Installation")
    element_tree.SubElement(installation, "InstallationTarget", Id="Microsoft.VisualStudio.Code")
    element_tree.SubElement(manifest, "Dependencies")
    assets = element_tree.SubElement(manifest, "Assets")
    element_tree.SubElement(
        assets,
        "Asset",
        Type="Microsoft.VisualStudio.Code.Manifest",
        Address="extension/package.json",
    )
    element_tree.SubElement(
        assets,
        "Asset",
        Type="Microsoft.VisualStudio.Services.Content.Details",
        Address="extension/README.md",
    )
    return element_tree.tostring(manifest, encoding="utf-8", xml_declaration=True)


def package_extension(source: Path, output: Path) -> None:
    package, _ = validate_extension(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", content_types())
        archive.writestr("extension.vsixmanifest", vsix_manifest(package))
        for source_file in sorted(source.rglob("*")):
            if source_file.is_file():
                archive.write(source_file, (Path("extension") / source_file.relative_to(source)).as_posix())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate source files without packaging")
    parser.add_argument("--output", type=Path, help="Path for the generated VSIX")
    arguments = parser.parse_args()

    try:
        validate_extension(EXTENSION_ROOT)
        if arguments.output:
            package_extension(EXTENSION_ROOT, arguments.output)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    if arguments.check:
        print("LAGC Tech Kiro IDE theme source is valid.")
    elif arguments.output:
        print(f"Created {arguments.output}")
    else:
        parser.error("pass --check or --output")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
