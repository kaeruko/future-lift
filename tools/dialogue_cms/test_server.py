"""Local CMS schema and atomic save regression checks."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from server import validate, write_document


def sample():
    source = json.loads((Path(__file__).resolve().parents[2] /
                         "assets/dialogues/dialogues.json").read_text("utf-8"))
    return source


class CmsTests(unittest.TestCase):
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
