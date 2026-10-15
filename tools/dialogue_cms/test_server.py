"""Local CMS schema and atomic save regression checks."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from server import validate, write_document
from characters import (load_catalog, validate_catalog, generate_dart, generate_pubspec,
                        DART, PUBSPEC, save_catalog_and_dialogues, validate_dialogue_ids)


def sample():
    source = json.loads((Path(__file__).resolve().parents[2] /
                         "assets/dialogues/dialogues.json").read_text("utf-8"))
    return source


class CmsTests(unittest.TestCase):
    def test_character_registry_and_generated_files(self):
        registry = validate_catalog(load_catalog())
        self.assertEqual(len(registry["characters"]), 7)
        self.assertEqual(generate_dart(DART.read_text("utf-8"), registry["characters"]),
                         DART.read_text("utf-8"))
        self.assertEqual(generate_pubspec(PUBSPEC.read_text("utf-8"), registry["characters"]),
                         PUBSPEC.read_text("utf-8"))

    def test_generated_dart_escapes_dollar_sign_in_names(self):
        entries = copy.deepcopy(load_catalog()["characters"])
        entries[0]["label"] = "価格$100"
        output = generate_dart(DART.read_text("utf-8"), entries)
        self.assertIn(r"価格\$100", output)

    def test_profile_updates_preserve_character_ids_and_generate_dart(self):
        original = load_catalog()
        modified = copy.deepcopy(original)
        modified["characters"][0]["profile"] = "おさんぽが好き。\n今日も一緒に歩こう！"
        self.assertIs(validate_catalog(modified, previous=original), modified)
        generated = generate_dart(DART.read_text("utf-8"), modified["characters"])
        self.assertIn(r"おさんぽが好き。\n今日も一緒に歩こう！", generated)

    def test_profile_requires_explicit_schema_and_valid_string(self):
        original = load_catalog()
        old_version = copy.deepcopy(original)
        old_version["version"] = 3
        with self.assertRaisesRegex(ValueError, "Unsupported character catalog version"):
            validate_catalog(old_version)

        missing = copy.deepcopy(original)
        del missing["characters"][0]["profile"]
        with self.assertRaisesRegex(ValueError, "Invalid character fields"):
            validate_catalog(missing, previous=original)

        for value in (None, 42, ["wrong"], "あ" * 1001):
            modified = copy.deepcopy(original)
            modified["characters"][0]["profile"] = value
            with self.subTest(value_type=type(value).__name__), self.assertRaisesRegex(ValueError, "Invalid profile"):
                validate_catalog(modified, previous=original)

        allowed = copy.deepcopy(original)
        allowed["characters"][0]["profile"] = "あ" * 1000
        validate_catalog(allowed, previous=original)

    def test_profile_dart_escapes_interpolation_and_quotes(self):
        characters = copy.deepcopy(load_catalog()["characters"])
        characters[0]["profile"] = '価格$100と"お話"'
        generated = generate_dart(DART.read_text("utf-8"), characters)
        self.assertIn(r'価格\$100と\"お話\"', generated)

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
            "artFolder": "999_owl", "nextDialogueNumber": 2,
            "profile": "",
            "inGacha": True, "walkInTown": True
        })
        with self.assertRaisesRegex(ValueError, "Sprite folder"):
            validate_catalog(modified, previous=original)
        modified["characters"][-1].update({
            "key": "c007_hitsuji", "id": "007_hitsuji",
            "label": "ひつじ", "artFolder": "007_hitsuji"
        })
        validate_catalog(modified, previous=original)
        with self.assertRaisesRegex(ValueError, "Missing"):
            validate(sample(), residents={row["id"] for row in modified["characters"]})

    def test_three_digit_id_generates_dart_key_and_folder(self):
        original = load_catalog()
        modified = copy.deepcopy(original)
        modified["characters"].append({
            "key": "c007_hitsuji", "id": "007_hitsuji", "label": "ひつじ",
            "artFolder": "007_hitsuji", "nextDialogueNumber": 2,
            "profile": "",
            "inGacha": True, "walkInTown": True
        })
        validate_catalog(modified, previous=original)
        dart = generate_dart(DART.read_text("utf-8"), modified["characters"])
        self.assertIn('c007_hitsuji("007_hitsuji", "ひつじ", "007_hitsuji"', dart)
        for field, value in (("key", "chef"), ("artFolder", "009_wrong")):
            mismatched = copy.deepcopy(modified)
            mismatched["characters"][-1][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "derived from ID"):
                validate_catalog(mismatched, previous=original)

    def test_dialogue_serials_preserve_existing_ids_and_retired_numbers(self):
        original = load_catalog()
        modified = copy.deepcopy(original)
        modified["characters"][0]["nextDialogueNumber"] = 3
        dialogues = sample()
        dialogues["dialogues"].append({
            "id": "01_shiba_001", "residentId": "01_shiba",
            "text": "新しい話", "priority": 0, "once": False,
            "logic": "all", "conditions": [],
        })
        dialogues["dialogues"].append({
            "id": "01_shiba_002", "residentId": "01_shiba",
            "text": "次の話", "priority": 0, "once": False,
            "logic": "all", "conditions": [],
        })
        validate_catalog(modified, previous=original)
        validate(dialogues)
        validate_dialogue_ids(modified, dialogues, original, sample())

        not_reserved = copy.deepcopy(modified)
        not_reserved["characters"][0]["nextDialogueNumber"] = 2
        with self.assertRaisesRegex(ValueError, "not reserved"):
            validate_dialogue_ids(not_reserved, dialogues, original, sample())

        previously_reserved = copy.deepcopy(original)
        previously_reserved["characters"][0]["nextDialogueNumber"] = 3
        future = copy.deepcopy(previously_reserved)
        future["characters"][0]["nextDialogueNumber"] = 4
        new_dialogues = sample()
        new_dialogues["dialogues"].append({
            "id": "01_shiba_002", "residentId": "01_shiba",
            "text": "削除済み番号の再利用", "priority": 0, "once": False,
            "logic": "all", "conditions": [],
        })
        with self.assertRaisesRegex(ValueError, "already reserved"):
            validate_dialogue_ids(future, new_dialogues, previously_reserved, sample())

        renamed = copy.deepcopy(dialogues)
        renamed["dialogues"][0]["residentId"] = "02_rabbit"
        with self.assertRaisesRegex(ValueError, "resident cannot change"):
            validate_dialogue_ids(modified, renamed, original, sample())

        invalid = copy.deepcopy(dialogues)
        invalid["dialogues"][-1]["id"] = "line_123"
        with self.assertRaisesRegex(ValueError, "character ID and serial"):
            validate_dialogue_ids(modified, invalid, original, sample())

        rollback_counter = copy.deepcopy(original)
        rollback_counter["characters"][0]["nextDialogueNumber"] = 3
        with self.assertRaisesRegex(ValueError, "cannot decrease"):
            validate_catalog(original, previous=rollback_counter)

    def test_bad_catalog_keeps_files_intact(self):
        original = load_catalog()
        modified = copy.deepcopy(original)
        modified["characters"][0]["key"] = "renamed"
        prior = {path: path.read_bytes() for path in (DART, PUBSPEC)}
        with self.assertRaises(ValueError):
            save_catalog_and_dialogues({"characters": modified, "dialogues": sample()}, validate)
        for path, raw in prior.items():
            self.assertEqual(path.read_bytes(), raw)

    def test_character_catalog_has_no_tip_source_or_dialogue_kinds(self):
        registry = validate_catalog(load_catalog())
        self.assertEqual(registry["version"], 4)
        for resident in registry["characters"]:
            self.assertNotIn("tipSource", resident)
        invalid = copy.deepcopy(registry)
        invalid["characters"][0]["tipSource"] = "adult"
        with self.assertRaisesRegex(ValueError, "Invalid character fields"):
            validate_catalog(invalid, previous=registry)
        dialogues = sample()
        self.assertEqual(dialogues["version"], 1)
        for entry in dialogues["dialogues"]:
            self.assertNotIn("kind", entry)
            self.assertIn("conditions", entry)
        validate(dialogues)

    def test_invalid_dialogue_fields_report_exact_missing_and_extra_keys(self):
        extra = sample()
        extra["dialogues"][0]["kind"] = "normal"
        with self.assertRaisesRegex(
                ValueError,
                r"dialogues\[0\]: invalid fields; missing=\[\], unexpected=\['kind'\]"):
            validate(extra)

        missing = sample()
        del missing["dialogues"][0]["logic"]
        with self.assertRaisesRegex(
                ValueError,
                r"dialogues\[0\]: invalid fields; missing=\['logic'\], unexpected=\[\]"):
            validate(missing)

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

    def test_town_companion_and_two_speaker_reply_validation(self):
        normal = sample()
        selected = normal["dialogues"][0]
        selected["conditions"] = [{"type": "townTogether", "otherResidentId": "02_rabbit"}]
        selected["reply"] = {"residentId": "02_rabbit", "text": "絵を描きたい！"}
        validate(normal)
        for condition in (
            {"type": "townTogether", "otherResidentId": "01_shiba"},
            {"type": "townTogether", "otherResidentId": "unknown"},
            {"type": "townTogether", "otherResidentId": 10},
            {"type": "townTogether"},
        ):
            with self.subTest(condition=condition):
                invalid = copy.deepcopy(normal)
                invalid["dialogues"][0]["conditions"] = [condition]
                with self.assertRaises(ValueError):
                    validate(invalid)
        invalid_reply = copy.deepcopy(normal)
        invalid_reply["dialogues"][0]["logic"] = "any"
        with self.assertRaisesRegex(ValueError, "matching AND"):
            validate(invalid_reply)
        invalid_reply = copy.deepcopy(normal)
        invalid_reply["dialogues"][0]["reply"] = {
            "residentId": "03_penguin", "text": "違う人の返事"}
        with self.assertRaisesRegex(ValueError, "matching AND"):
            validate(invalid_reply)
        invalid_reply = copy.deepcopy(normal)
        invalid_reply["dialogues"][0]["reply"]["text"] = " "
        with self.assertRaisesRegex(ValueError, "matching AND"):
            validate(invalid_reply)
        invalid_reply = copy.deepcopy(normal)
        invalid_reply["dialogues"][0]["reply"]["unknown"] = True
        with self.assertRaisesRegex(ValueError, "invalid fields"):
            validate(invalid_reply)

    def test_cross_character_seen_dialogue_reference(self):
        data = sample()
        prerequisite = data["dialogues"][5]["id"]
        dependent = data["dialogues"][0]
        self.assertNotEqual(data["dialogues"][5]["residentId"],
                            dependent["residentId"])
        dependent["conditions"] = [
            {"type": "seenDialogue", "dialogueId": prerequisite}]
        validate(data)

        removed = copy.deepcopy(data)
        removed["dialogues"] = [
            row for row in removed["dialogues"] if row["id"] != prerequisite]
        with self.assertRaisesRegex(ValueError, "Invalid prerequisite dialogue"):
            validate(removed)

        for bad in (dependent["id"], "missing", "", 42, None):
            invalid = copy.deepcopy(data)
            invalid["dialogues"][0]["conditions"] = [
                {"type": "seenDialogue", "dialogueId": bad}]
            with self.subTest(id=bad), self.assertRaises(ValueError):
                validate(invalid)

        missing_field = copy.deepcopy(data)
        missing_field["dialogues"][0]["conditions"] = [{"type": "seenDialogue"}]
        with self.assertRaises(ValueError):
            validate(missing_field)

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

    def test_dialogue_only_endpoint_cannot_allocate_without_counter(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "dialogues.json"
            with patch("server.DATA", target):
                write_document(sample())
                before = target.read_bytes()
                modified = sample()
                modified["dialogues"].append({
                    "id": "01_shiba_001", "residentId": "01_shiba",
                    "text": "新しい話", "priority": 0, "once": False,
                    "logic": "all", "conditions": [],
                })
                with self.assertRaisesRegex(ValueError, "Use /api/cms"):
                    write_document(modified)
                self.assertEqual(target.read_bytes(), before)

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
