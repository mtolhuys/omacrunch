#!/usr/bin/env python3
"""Read one pre-Store Omacrunch preference file for a one-time migration."""

from __future__ import annotations

import json
import os
import stat
import sys
from pathlib import Path


MAX_BYTES = 65_536
NAMES = {"widgets.json", "plugin-order.json"}
DIRECTORY_FLAGS = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
FILE_FLAGS = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)


def legacy_path(name: str, environment: dict[str, str]) -> Path:
    if name not in NAMES:
        raise ValueError("unsupported legacy state name")
    home = Path(environment["HOME"])
    state = Path(environment.get("XDG_STATE_HOME", str(home / ".local/state")))
    if not home.is_absolute() or not state.is_absolute() or home not in (state, *state.parents):
        raise ValueError("state directory is outside HOME")
    return state / "omarchy" / "omacrunch" / name


def read_capped(descriptor: int) -> bytes:
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = os.read(descriptor, min(65_536, MAX_BYTES + 1 - total))
        if not chunk:
            return b"".join(chunks)
        chunks.append(chunk)
        total += len(chunk)
        if total > MAX_BYTES:
            raise ValueError("legacy state exceeds its size limit")


def read_legacy(name: str, environment: dict[str, str] | None = None) -> object:
    path = legacy_path(name, dict(environment or os.environ))
    home = Path((environment or os.environ)["HOME"]).resolve(strict=False)
    relative = path.relative_to(home)
    descriptors: list[int] = []
    try:
        descriptors.append(os.open(home, DIRECTORY_FLAGS))
        for part in relative.parts[:-1]:
            descriptors.append(os.open(part, DIRECTORY_FLAGS, dir_fd=descriptors[-1]))
            directory = os.fstat(descriptors[-1])
            if not stat.S_ISDIR(directory.st_mode) or directory.st_uid != os.getuid() or directory.st_mode & 0o022:
                raise ValueError("legacy state has an unsafe parent directory")
        descriptors.append(os.open(relative.name, FILE_FLAGS, dir_fd=descriptors[-1]))
        info = os.fstat(descriptors[-1])
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("legacy state has unsafe ownership or permissions")
        if info.st_size > MAX_BYTES:
            raise ValueError("legacy state exceeds its size limit")
        payload = read_capped(descriptors[-1])
    finally:
        for descriptor in reversed(descriptors):
            os.close(descriptor)
    if len(payload) > MAX_BYTES:
        raise ValueError("legacy state exceeds its size limit")
    return json.loads(payload)


def main() -> int:
    if len(sys.argv) != 2:
        return 2
    try:
        value = read_legacy(sys.argv[1])
    except FileNotFoundError:
        return 3
    except (KeyError, OSError, ValueError, json.JSONDecodeError):
        return 4
    print(json.dumps(value, ensure_ascii=True, allow_nan=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
