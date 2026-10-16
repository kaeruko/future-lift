import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import release_version


class ReleaseVersionTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "pubspec.yaml"
        self.path.write_text("name: future_lift\nversion: 1.0.0+1\n", encoding="utf-8")

    def test_plan_and_persist(self):
        self.assertEqual(release_version.plan(self.path), {
            "build_name": "1.0.0",
            "source_version": "1.0.0+1",
            "next_build_number": 2,
        })
        release_version.persist(self.path, "1.0.0+1", 2)
        self.assertIn("version: 1.0.0+2\n", self.path.read_text())

    def test_rejects_stale_build(self):
        with self.assertRaisesRegex(ValueError, "Version changed"):
            release_version.persist(self.path, "1.0.0+4", 5)
        with self.assertRaisesRegex(ValueError, "Next build number"):
            release_version.persist(self.path, "1.0.0+1", 3)
        self.assertIn("version: 1.0.0+1", self.path.read_text())

    def test_invalid_version_fails_fast(self):
        self.path.write_text("version: 1.0.0\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "one version"):
            release_version.plan(self.path)


if __name__ == "__main__":
    unittest.main()
