"""Local CMS schema and atomic save regression checks."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from server import validate, write_document
from characters import (load_catalog, validate_catalog, generate_dart, generate_pubspec,
                        DART, PUBSPEC, save_catalog_and_dialogues)


def sample():
    source = json.loads((Path(__file__).resolve().parents[2] /
                         "assets/dialogues/dialogues.json").read_text("utf-8"))
    return source


class CmsTests(unittest.TestCase):
    def test_character_registry_and_generated_files(self):
        registry = validate_catalog(load_catalog())
        self.assertEqual(len(registry["characters"]), 6)
        self.assertEqual(generate_dart(DART.read_text("utf-8"), registry["characters"]),
                         DART.read_text("utf-8"))
        self.assertEqual(generate_pubspec(PUBSPEC.read_text("utf-8"), registry["characters"]),
                         PUBSPEC.read_text("utf-8"))

    def test_generated_dart_escapes_dollar_sign_in_names(self):
        entries = copy.deepcopy(load_catalog()["characters"])
        entries[0]["label"] = "価格$100"
        output = generate_dart(DART.read_text("utf-8"), entries)
        self.assertIn(r"価格\$100", output)

    def test_existing_character_ids_cannot_change(self):
        original = load_catalog()
        for change in ("remove", "id", "folder"):
            modified = copy.deepcopy(original)
            if change == "remove":
                modified["characters"].pop(0)
            elif change == "id":
                modified["characters"][0]["id"] = "01_new"
            else:
                modified["characters"][0]["artFolder"] = "002_usagi"
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_catalog(modified, previous=original)

    def test_new_character_needs_sprite_and_unconditional_dialogue(self):
        original = load_catalog()
        modified = copy.deepcopy(original)
        modified["characters"].append({
            "key": "c999_owl", "id": "999_owl", "label": "ふくろう",
            "artFolder": "999_owl", "tipSource": "adult",
            "inGacha": True, "walkInTown": True
        })
        with self.assertRaisesRegex(ValueError, "Sprite folder"):
            validate_catalog(modified, previous=original)
        modified["characters"][-1].update({
            "key": "c009_chef", "id": "009_chef", "label": "シェフ", "artFolder": "009_chef"
        })
        validate_catalog(modified, previous=original)
        with self.assertRaisesRegex(ValueError, "Missing"):
            validate(sample(), residents={row["id"] for row in modified["characters"]})

    def test_three_digit_id_generates_dart_key_and_folder(self):
        original = load_catalog()
        modified = copy.deepcopy(original)
        modified["characters"].append({
            "key": "c009_chef", "id": "009_chef", "label": "シェフ",
            "artFolder": "009_chef", "tipSource": "adult",
            "inGacha": True, "walkInTown": True
        })
        validate_catalog(modified, previous=original)
        dart = generate_dart(DART.read_text("utf-8"), modified["characters"])
        self.assertIn('c009_chef("009_chef", "シェフ", "009_chef"', dart)
        for field, value in (("key", "chef"), ("artFolder", "009_wrong")):
            mismatched = copy.deepcopy(modified)
            mismatched["characters"][-1][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "derived from ID"):
                validate_catalog(mismatched, previous=original)

    def test_bad_catalog_keeps_files_intact(self):
        original = load_catalog()
        modified = copy.deepcopy(original)
        modified["characters"][0]["key"] = "renamed"
        prior = {path: path.read_bytes() for path in (DART, PUBSPEC)}
        with self.assertRaises(ValueError):
            save_catalog_and_dialogues({"characters": modified, "dialogues": sample()}, validate)
        for path, raw in prior.items():
            self.assertEqual(path.read_bytes(), raw)

    def test_valid_bundled_content(self):
        validate(sample())

    def test_rejects_invalid_dates_and_missions(self):
        for bad in (
            {"type": "date", "mode": "exact", "date": "2026-02-30"},
            {"type": "date", "mode": "range", "start": "2026-10-22", "end": "2026-10-10"},
            {"type": "date", "mode": "annual", "date": "13-01"},
            {"type": "date", "mode": "weekday", "days": [0]},
            {"type": "mission", "missionId": "unknown", "minCount": 2},
            {"type": "kotohogi", "min": -1},
        ):
            with self.subTest(bad=bad):
                doc = sample()
                doc["dialogues"][-1]["conditions"] = [bad]
                with self.assertRaises(ValueError):
                    validate(doc)

    def test_save_is_atomic_and_invalid_changes_leave_old_file(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "dialogues.json"
            with patch("server.DATA", target):
                good = sample()
                write_document(good)
                prior = target.read_bytes()
                invalid = copy.deepcopy(good)
                invalid["dialogues"][0]["residentId"] = "invalid"
                with self.assertRaises(ValueError):
                    write_document(invalid)
                self.assertEqual(target.read_bytes(), prior)
                self.assertEqual(json.loads(prior)["version"], 1)

    def test_every_resident_needs_fallback_line(self):
        doc = sample()
        doc["dialogues"] = [
            e for e in doc["dialogues"]
            if e["residentId"] != "01_shiba" or e["conditions"]
        ]
        with self.assertRaises(ValueError):
            validate(doc)


if __name__ == "__main__":
    unittest.main()
