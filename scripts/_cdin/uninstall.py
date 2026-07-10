from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from .platform import PLATFORM, EXE_NAME, default_prefix
from .ui import banner, info, ok, dim
from .ui import prompt_yn


def cmd_uninstall(args: argparse.Namespace) -> None:
    banner("UNINSTALL")

    prefix  = Path(getattr(args, "prefix", None) or default_prefix())
    bin_dir = prefix / "bin"

    if not prompt_yn(f"Remove cdin from {prefix}?", default=False):
        info("Cancelled.")
        return

    removed: list[str] = []

    _remove_binary(bin_dir, removed)
    _remove_data(bin_dir, removed)
    _remove_platform_extras(prefix, bin_dir, removed)

    for r in removed:
        dim(f"  removed: {r}")

    ok("Uninstall complete.")

def _remove_binary(bin_dir: Path, removed: list[str]) -> None:
    for name in ("cdin", "cdin.exe"):
        exe = bin_dir / name
        if exe.is_file():
            exe.unlink()
            removed.append(str(exe))


def _remove_data(bin_dir: Path, removed: list[str]) -> None:
    data_dir = bin_dir / "data"
    if data_dir.is_dir():
        shutil.rmtree(data_dir)
        removed.append(str(data_dir))


def _remove_path(path: Path, removed: list[str]) -> None:
    """Unlink a file or rmtree a directory if it exists."""
    if path.is_file():
        path.unlink()
        removed.append(str(path))
    elif path.is_dir():
        shutil.rmtree(path)
        removed.append(str(path))

def _remove_platform_extras(prefix: Path, bin_dir: Path, removed: list[str]) -> None:
    if PLATFORM == "linux":
        _remove_linux(prefix, removed)
    elif PLATFORM == "windows":
        _remove_windows(prefix, bin_dir, removed)
    elif PLATFORM == "macos":
        _remove_macos(removed)


def _remove_linux(prefix: Path, removed: list[str]) -> None:
    hicolor = prefix / "share" / "icons" / "hicolor"
    for sub in hicolor.rglob("cdin.*"):
        sub.unlink(missing_ok=True)
        removed.append(str(sub))

    _remove_path(prefix / "share" / "applications" / "cdin.desktop", removed)


def _remove_windows(prefix: Path, bin_dir: Path, removed: list[str]) -> None:
    desktop   = Path(os.environ.get("USERPROFILE", "~")).expanduser() / "Desktop" / "cdin.lnk"
    startmenu = (Path(os.environ.get("APPDATA", ""))
                 / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "cdin.lnk")

    for lnk in (desktop, startmenu):
        _remove_path(lnk, removed)

    _remove_path(prefix / "cdin.ico", removed)
    _remove_from_path_windows(bin_dir)


def _remove_from_path_windows(bin_dir: Path) -> None:
    try:
        import winreg
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment", 0, winreg.KEY_ALL_ACCESS)
        try:
            cur, _ = winreg.QueryValueEx(key, "PATH")
            new = ";".join(p for p in cur.split(";") if p and Path(p) != bin_dir)
            winreg.SetValueEx(key, "PATH", 0, winreg.REG_EXPAND_SZ, new)
            ok(f"Removed {bin_dir} from PATH.")
        except FileNotFoundError:
            pass
        winreg.CloseKey(key)
    except Exception:
        pass


def _remove_macos(removed: list[str]) -> None:
    _remove_path(Path("/Applications/cdin.app"), removed)
