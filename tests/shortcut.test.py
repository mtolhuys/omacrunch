import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("omacrunch_shortcut", ROOT / "shortcut.py")
shortcut = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = shortcut
SPEC.loader.exec_module(shortcut)


class ShortcutTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.bindings = self.root / ".config" / "hypr" / "bindings.lua"
        self.bindings.parent.mkdir(parents=True)
        self.bindings.write_text('-- personal bindings\n', encoding="utf-8")
        self.environment = {"HOME": str(self.root)}

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def live_crunch():
        return [{"key": "C", "modmask": 72, "description": "Crunch menu"}]

    def test_free_conflicting_and_owned_classification(self):
        with mock.patch.object(shortcut, "_live_bindings", return_value=[]):
            self.assertEqual(shortcut.inspect(self.environment).classification, "free")

            self.bindings.write_text('o.bind("SUPER + ALT + C", "Mine", "something")\n', encoding="utf-8")
            self.assertEqual(shortcut.inspect(self.environment).classification, "personal-conflict")

            self.bindings.write_text(shortcut.MANAGED_BLOCK, encoding="utf-8")
        with mock.patch.object(shortcut, "_live_bindings", return_value=self.live_crunch()):
            self.assertEqual(shortcut.inspect(self.environment).classification, "owned")

    def test_comments_do_not_claim_the_chord(self):
        self.bindings.write_text('-- SUPER + ALT + C is intentionally available\n', encoding="utf-8")
        with mock.patch.object(shortcut, "_live_bindings", return_value=[]):
            self.assertEqual(shortcut.inspect(self.environment).classification, "free")

    def test_partial_managed_marker_is_ambiguous(self):
        self.bindings.write_text(shortcut.BEGIN + "\n", encoding="utf-8")
        with mock.patch.object(shortcut, "_live_bindings", return_value=[]):
            self.assertEqual(shortcut.inspect(self.environment).classification, "ambiguous")

    def test_install_and_remove_are_exact_and_reversible(self):
        original = self.bindings.read_bytes()

        def live_from_file():
            text = self.bindings.read_text(encoding="utf-8")
            return self.live_crunch() if shortcut.MANAGED_BLOCK in text else []

        with mock.patch.object(shortcut, "_live_bindings", side_effect=live_from_file), \
                mock.patch.object(shortcut, "_reload_expect"):
            installed = shortcut.install(self.environment)
            self.assertEqual(installed["result"], "installed")
            self.assertEqual(installed["classification"], "owned")
            self.assertEqual(self.bindings.read_bytes(), original + shortcut.MANAGED_BLOCK.encode())

            removed = shortcut.remove(self.environment)
            self.assertEqual(removed["result"], "removed")
            self.assertEqual(removed["classification"], "free")
            self.assertEqual(self.bindings.read_bytes(), original)

        backups = list(self.bindings.parent.glob("bindings.lua.omacrunch-backup-*"))
        self.assertEqual(len(backups), 2)
        self.assertTrue(all((path.stat().st_mode & 0o777) == 0o600 for path in backups))
        self.assertEqual({path.read_bytes() for path in backups}, {
            original,
            original + shortcut.MANAGED_BLOCK.encode(),
        })

    def test_large_backup_is_complete_and_private(self):
        original = (b"# personal binding\n" * 16384)[:300000]
        backup = shortcut._backup(self.bindings, original)
        self.assertEqual(backup.read_bytes(), original)
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)

    def test_conflict_refuses_without_mutation(self):
        original = b'o.bind("SUPER + ALT + C", "Mine", "something")\n'
        self.bindings.write_bytes(original)
        live = [{"key": "C", "modmask": "72", "description": "Mine"}]
        with mock.patch.object(shortcut, "_live_bindings", return_value=live):
            with self.assertRaises(shortcut.ShortcutError):
                shortcut.install(self.environment)
        self.assertEqual(self.bindings.read_bytes(), original)
        self.assertEqual(list(self.bindings.parent.glob("bindings.lua.omacrunch-backup-*")), [])

    def test_status_exit_codes_are_stable_for_qml(self):
        self.assertEqual(shortcut.STATUS_EXIT_CODES, {
            "free": 0,
            "owned": 10,
            "personal-conflict": 11,
            "ambiguous": 12,
        })


if __name__ == "__main__":
    unittest.main()
