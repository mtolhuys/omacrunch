import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location(
    "legacy_state", Path(__file__).parents[1] / "legacy-state.py"
)
legacy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(legacy)


class LegacyState(unittest.TestCase):
    def environment(self, home: Path) -> dict[str, str]:
        return {"HOME": str(home), "XDG_STATE_HOME": str(home / "state")}

    def path(self, home: Path, name: str = "widgets.json") -> Path:
        return home / "state/omarchy/omacrunch" / name

    def test_reads_owned_bounded_json(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = self.path(home)
            path.parent.mkdir(parents=True)
            value = {"version": 1, "screens": {}, "weatherCity": "Den Helder"}
            path.write_text(json.dumps(value), encoding="utf-8")
            self.assertEqual(legacy.read_legacy("widgets.json", self.environment(home)), value)

    def test_rejects_unknown_name_symlink_and_group_writable_file(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = self.path(home)
            path.parent.mkdir(parents=True)
            path.write_text("{}", encoding="utf-8")
            with self.assertRaises(ValueError):
                legacy.read_legacy("other.json", self.environment(home))
            path.chmod(0o664)
            with self.assertRaises(ValueError):
                legacy.read_legacy("widgets.json", self.environment(home))
            path.unlink()
            target = home / "target.json"
            target.write_text("{}", encoding="utf-8")
            path.symlink_to(target)
            with self.assertRaises((OSError, ValueError)):
                legacy.read_legacy("widgets.json", self.environment(home))

    def test_rejects_state_outside_home_and_oversize(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
            home = Path(directory)
            with self.assertRaises(ValueError):
                legacy.legacy_path("widgets.json", {"HOME": str(home), "XDG_STATE_HOME": outside})
            path = self.path(home)
            path.parent.mkdir(parents=True)
            path.write_bytes(b" " * (legacy.MAX_BYTES + 1))
            with self.assertRaises(ValueError):
                legacy.read_legacy("widgets.json", self.environment(home))

    def test_rejects_symlinked_parent(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            real = home / "real/omacrunch"
            real.mkdir(parents=True)
            (real / "widgets.json").write_text("{}", encoding="utf-8")
            state = home / "state"
            state.mkdir()
            (state / "omarchy").symlink_to(home / "real", target_is_directory=True)
            with self.assertRaises(OSError):
                legacy.read_legacy("widgets.json", self.environment(home))


if __name__ == "__main__":
    unittest.main()
