#!/usr/bin/env python3
"""Explicit, reversible ownership of Omacrunch's menu shortcut."""

from __future__ import annotations

import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


CHORD = "SUPER + ALT + C"
MODMASK = 72
KEY = "C"
DESCRIPTION = "Crunch menu"
COMMAND = "omarchy-shell shell summon io.github.mtolhuys.omacrunch"
BEGIN = "-- BEGIN OMACRUNCH MANAGED SHORTCUT"
END = "-- END OMACRUNCH MANAGED SHORTCUT"
MANAGED_BLOCK = (
    f"\n{BEGIN}\n"
    f'o.bind("{CHORD}", "{DESCRIPTION}", "{COMMAND}")\n'
    f"{END}\n"
)
STATUS_EXIT_CODES = {
    "free": 0,
    "owned": 10,
    "personal-conflict": 11,
    "ambiguous": 12,
}


class ShortcutError(RuntimeError):
    """A safe shortcut mutation could not be proven."""


@dataclass(frozen=True)
class ShortcutStatus:
    classification: str
    bindings_file: Path
    live_matches: tuple[Mapping[str, Any], ...]
    message: str

    def public(self) -> dict[str, Any]:
        return {
            "classification": self.classification,
            "binding": CHORD,
            "bindingsFile": str(self.bindings_file),
            "message": self.message,
            "liveActions": [
                {
                    "description": str(item.get("description") or ""),
                    "dispatcher": str(item.get("dispatcher") or ""),
                    "arg": str(item.get("arg") or ""),
                }
                for item in self.live_matches
            ],
        }


def _bindings_path(environment: Mapping[str, str]) -> Path:
    home = environment.get("HOME")
    if not home:
        raise ShortcutError("HOME must be set")
    config_root = Path(environment.get("XDG_CONFIG_HOME", str(Path(home) / ".config")))
    return config_root / "hypr" / "bindings.lua"


def _owned_regular_file(path: Path) -> os.stat_result:
    if path.is_symlink():
        raise ShortcutError(f"refusing symlinked configuration: {path}")
    try:
        info = path.stat()
    except FileNotFoundError as exc:
        raise ShortcutError(f"binding file does not exist: {path}") from exc
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        raise ShortcutError(f"binding file is not an owned regular file: {path}")
    return info


def _read_text(path: Path, maximum: int = 1024 * 1024) -> str:
    info = _owned_regular_file(path)
    if info.st_size > maximum:
        raise ShortcutError(f"binding file exceeds {maximum} bytes: {path}")
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise ShortcutError(f"cannot read UTF-8 configuration: {path}") from exc


def _active_personal_mentions(text: str) -> list[str]:
    mentions: list[str] = []
    for line in text.splitlines():
        code = line.split("--", 1)[0]
        compact = re.sub(r"\s+", "", code).upper()
        if "SUPER+ALT+C" in compact or "ALT+SUPER+C" in compact:
            mentions.append(line)
    return mentions


def _hyprctl(arguments: Sequence[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["hyprctl", *arguments],
            check=False,
            capture_output=True,
            text=True,
            timeout=8,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise ShortcutError("hyprctl could not inspect the live session") from exc


def _live_bindings() -> list[Mapping[str, Any]]:
    completed = _hyprctl(["binds", "-j"])
    if completed.returncode != 0 or len(completed.stdout) > 2 * 1024 * 1024:
        raise ShortcutError("hyprctl binds -j failed or exceeded its bound")
    try:
        values = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise ShortcutError("hyprctl binds -j returned invalid JSON") from exc
    if not isinstance(values, list):
        raise ShortcutError("hyprctl binds -j returned an unexpected shape")
    return [item for item in values if isinstance(item, dict)]


def _is_chord(item: Mapping[str, Any]) -> bool:
    if str(item.get("key") or "").upper() != KEY:
        return False
    raw_modmask = item.get("modmask")
    if not isinstance(raw_modmask, (int, str)) or isinstance(raw_modmask, bool):
        return False
    try:
        return int(raw_modmask) == MODMASK
    except (TypeError, ValueError):
        return False


def inspect(environment: Mapping[str, str] | None = None) -> ShortcutStatus:
    env = dict(environment or os.environ)
    bindings_file = _bindings_path(env)
    personal = _read_text(bindings_file)
    live = tuple(item for item in _live_bindings() if _is_chord(item))
    begin_count = personal.count(BEGIN)
    end_count = personal.count(END)
    block_count = personal.count(MANAGED_BLOCK)
    mentions = _active_personal_mentions(personal)

    if block_count == 1 and begin_count == 1 and end_count == 1 and len(live) == 1:
        if str(live[0].get("description") or "") == DESCRIPTION:
            return ShortcutStatus("owned", bindings_file, live, "Omacrunch owns the exact shortcut block.")
        return ShortcutStatus("ambiguous", bindings_file, live, "The managed block exists but its live action differs.")
    if begin_count or end_count:
        return ShortcutStatus("ambiguous", bindings_file, live, "A partial or edited Omacrunch shortcut block exists.")
    if len(live) > 1:
        return ShortcutStatus("ambiguous", bindings_file, live, "More than one live action uses Super+Alt+C.")
    if mentions:
        return ShortcutStatus("personal-conflict", bindings_file, live, "Personal bindings already mention Super+Alt+C.")
    if not live:
        return ShortcutStatus("free", bindings_file, live, "Super+Alt+C is free.")
    return ShortcutStatus("personal-conflict", bindings_file, live, "Super+Alt+C already has a live action.")


def _atomic_preserving(path: Path, data: bytes, mode: int) -> None:
    _owned_regular_file(path)
    descriptor = -1
    temporary = ""
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.omacrunch.", dir=path.parent)
        os.fchmod(descriptor, stat.S_IMODE(mode))
        with os.fdopen(descriptor, "wb", closefd=True) as handle:
            descriptor = -1
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        temporary = ""
        directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except OSError as exc:
        raise ShortcutError("could not write bindings atomically") from exc
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        if temporary:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


def _backup(path: Path, original: bytes) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = path.with_name(f"{path.name}.omacrunch-backup-{stamp}")
    index = 1
    while backup.exists() and index < 100:
        backup = path.with_name(f"{path.name}.omacrunch-backup-{stamp}-{index}")
        index += 1
    if backup.exists():
        raise ShortcutError("could not allocate a unique private backup")
    descriptor = os.open(backup, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    try:
        os.write(descriptor, original)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    return backup


def _reload_expect(*, installed: bool) -> None:
    if _hyprctl(["reload"]).returncode != 0:
        raise ShortcutError("Hyprland reload failed")
    errors = _hyprctl(["configerrors"])
    if errors.returncode != 0 or errors.stdout.strip():
        raise ShortcutError("Hyprland reported configuration errors")
    matches = [item for item in _live_bindings() if _is_chord(item)]
    if installed:
        if len(matches) != 1 or str(matches[0].get("description") or "") != DESCRIPTION:
            raise ShortcutError("live validation did not find exactly one Crunch menu action")
    elif matches:
        raise ShortcutError("live validation did not release Super+Alt+C")


def install(environment: Mapping[str, str] | None = None) -> dict[str, Any]:
    if os.geteuid() == 0:
        raise ShortcutError("shortcut setup refuses to run as root")
    status = inspect(environment)
    if status.classification == "owned":
        return {"result": "unchanged", **status.public()}
    if status.classification != "free":
        raise ShortcutError(status.message)

    info = _owned_regular_file(status.bindings_file)
    original = status.bindings_file.read_bytes()
    backup = _backup(status.bindings_file, original)
    try:
        _atomic_preserving(status.bindings_file, original + MANAGED_BLOCK.encode(), info.st_mode)
        _reload_expect(installed=True)
    except Exception as exc:
        _atomic_preserving(status.bindings_file, original, info.st_mode)
        try:
            _reload_expect(installed=False)
        except ShortcutError as recovery:
            raise ShortcutError(f"installation and recovery validation failed: {recovery}") from exc
        raise ShortcutError("shortcut installation failed; original bindings were restored") from exc
    return {"result": "installed", **inspect(environment).public(), "backup": str(backup)}


def remove(environment: Mapping[str, str] | None = None) -> dict[str, Any]:
    if os.geteuid() == 0:
        raise ShortcutError("shortcut setup refuses to run as root")
    status = inspect(environment)
    if status.classification == "free":
        return {"result": "unchanged", **status.public()}
    if status.classification != "owned":
        raise ShortcutError("Omacrunch does not own one exact unmodified shortcut block; removal refused")

    info = _owned_regular_file(status.bindings_file)
    original = status.bindings_file.read_bytes()
    text = original.decode("utf-8")
    if text.count(MANAGED_BLOCK) != 1:
        raise ShortcutError("managed block is edited or ambiguous; removal refused")
    backup = _backup(status.bindings_file, original)
    try:
        _atomic_preserving(status.bindings_file, text.replace(MANAGED_BLOCK, "", 1).encode(), info.st_mode)
        _reload_expect(installed=False)
    except Exception as exc:
        _atomic_preserving(status.bindings_file, original, info.st_mode)
        try:
            _reload_expect(installed=True)
        except ShortcutError as recovery:
            raise ShortcutError(f"removal and recovery validation failed: {recovery}") from exc
        raise ShortcutError("shortcut removal failed; managed block was restored") from exc
    return {"result": "removed", **inspect(environment).public(), "backup": str(backup)}


def main(arguments: Sequence[str] | None = None) -> int:
    values = list(arguments or sys.argv[1:])
    allowed = {"status", "install", "remove", "status-code", "install-quiet", "remove-quiet"}
    if len(values) != 1 or values[0] not in allowed:
        print(json.dumps({"ok": False, "message": "usage: shortcut.py status|install|remove"}))
        return 2
    action = values[0]
    quiet = action in {"status-code", "install-quiet", "remove-quiet"}
    try:
        if action == "status-code":
            return STATUS_EXIT_CODES.get(inspect().classification, 20)
        if action == "status":
            result = inspect().public()
        elif action in {"install", "install-quiet"}:
            result = install()
        else:
            result = remove()
        if not quiet:
            print(json.dumps({"protocolVersion": 1, "ok": True, "action": action, **result}, sort_keys=True))
        return 0
    except ShortcutError as exc:
        if not quiet:
            print(json.dumps({"protocolVersion": 1, "ok": False, "action": action, "message": str(exc)}, sort_keys=True))
        return 20 if quiet else 2


if __name__ == "__main__":
    raise SystemExit(main())
