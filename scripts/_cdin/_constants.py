"""
_cdin/_constants.py — Project-wide constants and computed paths.
"""

from __future__ import annotations

from pathlib import Path

REPO            = "m-mdy-m/cdin"
GITHUB_RELEASES = f"https://api.github.com/repos/{REPO}/releases"

SCRIPT_DIR = Path(__file__).resolve().parent.parent
ROOT_DIR   = SCRIPT_DIR.parent

ICON_SVG    = ROOT_DIR / "scripts" / "icon.svg"
ICON_ICO    = SCRIPT_DIR / "cdin.ico"      # pre-built Windows icon, if present
GEN_ICON_PY = ROOT_DIR / "scripts" / "gen_icon.py"
GEN_LOGO_PY = ROOT_DIR / "scripts" / "gen_logo_lua.py"
ICON_INL    = ROOT_DIR / "src" / "icon.inl"

def _exe(name: str = "cdin") -> str:
    """Return platform-correct executable name (lazy import avoids circularity)."""
    import platform as _plat
    return f"{name}.exe" if _plat.system() == "Windows" else name

_BUILD_TYPES    = ("release", "debug")
_BUILD_PLATFORMS = ("linux", "macos", "windows")

def build_output_candidates(build_type: str = "release") -> list[Path]:
    exe = _exe()
    return [
        ROOT_DIR / "build" / f"{p}-{build_type}" / exe
        for p in _BUILD_PLATFORMS
    ] + [
        ROOT_DIR / "build" / exe,
        ROOT_DIR / "bin"   / exe,
        ROOT_DIR           / exe,
    ]
