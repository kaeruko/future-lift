"""Validated character registry for the local CMS.

Saves a catalog, dialogue data, generated Flutter enum and asset manifest.
Existing resident IDs never change so stored collections remain readable.
"""
from __future__ import annotations

import json
import os
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "assets" / "characters" / "characters.json"
DART = ROOT / "lib" / "resident_collection.dart"
PUBSPEC = ROOT / "pubspec.yaml"
DIALOGUES = ROOT / "assets" / "dialogues" / "dialogues.json"
DART_START = "  // BEGIN CMS RESIDENTS"
DART_END = "  // END CMS RESIDENTS"
ASSETS_START = "    # BEGIN CMS CHARACTER ASSETS"
ASSETS_END = "    # END CMS CHARACTER ASSETS"
FIELDS = {"key", "id", "label", "artFolder", "tipSource", "inGacha", "walkInTown"}
DIRECTIONS = ("front", "back", "left", "right")


def load_catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def validate_catalog(document, previous=None, *, characters_root=None):
    if not isinstance(document, dict) or set(document) != {"version", "characters"}:
        raise ValueError("Invalid character catalog root")
    if type(document["version"]) is not int or document["version"] != 1:
        raise ValueError("Unsupported character catalog version")
    characters = document["characters"]
    if not isinstance(characters, list) or not 1 <= len(characters) <= 64:
        raise ValueError("Characters must contain 1-64 residents")
    ids, keys, folders = set(), set(), set()
    root = characters_root if characters_root is not None else CATALOG.parent
    for index, row in enumerate(characters):
        if not isinstance(row, dict) or set(row) != FIELDS:
            raise ValueError(f"Invalid character fields at row {index}")
        key, identifier, folder = row["key"], row["id"], row["artFolder"]
        if not isinstance(key, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", key):
            raise ValueError(f"Invalid character key at row {index}")
        if key in {"values", "index", "name", "byName", "id", "label", "artFolder",
                   "tipSource", "inGacha", "walkInTown", "gachaPool",
                   "abstract", "as", "assert", "async", "await", "base", "break",
                   "case", "catch", "class", "const", "continue", "covariant",
                   "default", "deferred", "do", "dynamic", "else", "enum",
                   "export", "extends", "extension", "external", "factory",
                   "false", "final", "finally", "for", "Function", "get",
                   "hide", "if", "implements", "import", "in", "interface",
                   "is", "late", "library", "mixin", "new", "null", "on",
                   "operator", "part", "required", "rethrow", "return",
                   "sealed", "set", "show", "static", "super", "switch",
                   "sync", "this", "throw", "true", "try", "typedef", "var",
                   "void", "when", "while", "with", "yield"}:
            raise ValueError(f"Reserved character key: {key}")
        if not isinstance(identifier, str) or not re.fullmatch(r"[0-9]{2}_[a-z][a-z0-9_]*", identifier):
            raise ValueError(f"Invalid resident ID at row {index}")
        if not isinstance(folder, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", folder) or ".." in folder:
            raise ValueError(f"Invalid sprite folder at row {index}")
        if not isinstance(row["label"], str) or not 1 <= len(row["label"].strip()) <= 40:
            raise ValueError(f"Invalid resident name at row {index}")
        if row["tipSource"] not in {"child", "student", "adult", "elder"}:
            raise ValueError(f"Invalid tip source at row {index}")
        if type(row["inGacha"]) is not bool or type(row["walkInTown"]) is not bool:
            raise ValueError(f"Invalid resident flags at row {index}")
        if identifier in ids or key in keys or folder in folders:
            raise ValueError(f"Duplicate resident ID, key, or sprite folder at row {index}")
        ids.add(identifier)
        keys.add(key)
        folders.add(folder)
        directory = root / folder
        if not directory.is_dir() or not directory.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Sprite folder not found: {folder}")
        required = ["idle_front_01.png", "clap_front_01.png", "clap_front_02.png"]
        required += [
            f"walk_{direction}_{frame:02d}.png"
            for direction in DIRECTIONS
            for frame in range(1, 5)
            if not (identifier == "01_shiba" and direction == "left")
        ]
        missing = [name for name in required if not (directory / name).is_file()]
        if missing:
            raise ValueError(f"Missing sprite in {folder}: {missing[0]}")
    if not any(row["inGacha"] for row in characters):
        raise ValueError("At least one resident must be available in gacha")
    if previous is not None:
        prior = previous["characters"]
        if len(characters) < len(prior):
            raise ValueError("Existing residents cannot be removed (saved data uses their IDs)")
        for index, old in enumerate(prior):
            new = characters[index]
            if any(old[field] != new[field] for field in ("key", "id", "artFolder")):
                raise ValueError(f"Existing resident identity cannot change: {old['id']}")
    return document


def replace_section(source, start, end, lines):
    if source.count(start) != 1 or source.count(end) != 1:
        raise ValueError(f"Generated section marker missing or duplicated: {start}")
    before, remainder = source.split(start, 1)
    _, after = remainder.split(end, 1)
    return before + start + "\n" + lines + "\n" + end + after


def generate_dart(source, characters):
    declarations = []
    for row in characters:
        # Dart interpolates dollar signs inside quoted strings; preserve literal labels.
        label = json.dumps(row["label"], ensure_ascii=False).replace("$", r"\$")
        declarations.append(
            f'  {row["key"]}("{row["id"]}", {label}, "{row["artFolder"]}", '
            f'Resident.{row["tipSource"]}, '
            f'{"true" if row["inGacha"] else "false"}, '
            f'{"true" if row["walkInTown"] else "false"})'
        )
    return replace_section(source, DART_START, DART_END, ",\n".join(declarations))


def generate_pubspec(source, characters):
    # The tutorial character is registered separately, without gacha access.
    folders = sorted({row["artFolder"] for row in characters
                      if row["artFolder"] != "013_kotohogisu"})
    rows = "\n".join(f"    - assets/characters/{folder}/" for folder in folders)
    return replace_section(source, ASSETS_START, ASSETS_END, rows)


def commit_files(contents):
    """Stage all files before writing, restoring earlier replacements on failure."""
    originals = {}
    staged = []
    replaced = []
    try:
        for path, text in contents.items():
            originals[path] = path.read_bytes()
            with tempfile.NamedTemporaryFile(
                "wb", dir=path.parent, prefix=".kotohogu-cms-", suffix=".tmp",
                delete=False
            ) as tmp:
                tmp.write(text.encode("utf-8"))
                tmp.flush()
                os.fsync(tmp.fileno())
                staged.append((Path(tmp.name), path))
        try:
            for tmp, path in staged:
                os.replace(tmp, path)
                replaced.append(path)
        except OSError as original_error:
            rollback_errors = []
            for path in reversed(replaced):
                try:
                    with tempfile.NamedTemporaryFile(
                        "wb", dir=path.parent, prefix=".kotohogu-rollback-",
                        suffix=".tmp", delete=False
                    ) as restored:
                        restored.write(originals[path])
                        restored.flush()
                        os.fsync(restored.fileno())
                        recovery = restored.name
                    try:
                        os.replace(recovery, path)
                    finally:
                        if os.path.exists(recovery):
                            os.unlink(recovery)
                except OSError as rollback_error:
                    rollback_errors.append(f"{path}: {rollback_error}")
            if rollback_errors:
                raise OSError(f"CMS write failed: {original_error}; "
                              f"rollback failed: {'; '.join(rollback_errors)}") from original_error
            raise
    finally:
        for temp, _ in staged:
            if temp.exists():
                temp.unlink()


def save_catalog_and_dialogues(payload, validate_dialogues):
    if not isinstance(payload, dict) or set(payload) != {"characters", "dialogues"}:
        raise ValueError("Expected character catalog and dialogue document")
    previous = load_catalog()
    catalog = validate_catalog(payload["characters"], previous=previous)
    ids = {row["id"] for row in catalog["characters"]}
    dialogues = validate_dialogues(payload["dialogues"], residents=ids)
    dart = generate_dart(DART.read_text(encoding="utf-8"), catalog["characters"])
    pubspec = generate_pubspec(PUBSPEC.read_text(encoding="utf-8"), catalog["characters"])
    commit_files({
        CATALOG: json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        DIALOGUES: json.dumps(dialogues, ensure_ascii=False, indent=2) + "\n",
        DART: dart,
        PUBSPEC: pubspec,
    })
    return {"ok": True, "characters": len(catalog["characters"]),
            "dialogues": len(dialogues["dialogues"])}
