from __future__ import annotations

import os
import platform
from pathlib import Path


def detect_platform() -> str:
    s = platform.system()
    if s == "Linux":
        return "linux"
    if s == "Darwin":
        return "macos"
    if s == "Windows" or any(x in s for x in ("MINGW", "MSYS", "CYGWIN")):
        return "windows"
    return "unknown"


PLATFORM = detect_platform()
EXE_SUFFIX = ".exe" if PLATFORM == "windows" else ""
EXE_NAME   = f"cdin{EXE_SUFFIX}"


def default_prefix() -> Path:
    if PLATFORM == "windows":
        local = os.environ.get("LOCALAPPDATA", "")
        return Path(local) / "cdin" if local else Path.home() / "AppData" / "Local" / "cdin"
    return Path.home() / ".local"


def default_jobs() -> int:
    try:
        return os.cpu_count() or 4
    except Exception:
        return 4
