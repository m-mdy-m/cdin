"""
_cdin/utils.py — Shared runtime helpers: subprocess, filesystem, version, binary ops.
"""

from __future__ import annotations

import re
import shutil
import stat
import subprocess
import tarfile
import zipfile
from pathlib import Path
from typing import Optional

from ._constants import ROOT_DIR, build_output_candidates
from .platform import PLATFORM, EXE_NAME, default_prefix
from .ui import die, ok, warn


def run(cmd: list, cwd: Optional[Path] = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run a command, streaming stdout/stderr."""
    return subprocess.run(cmd, cwd=cwd or ROOT_DIR, check=check)


def require(tool: str, hint: str = "") -> str:
    path = shutil.which(tool)
    if not path:
        msg = f"'{tool}' not found."
        if hint:
            msg += f"\n         {hint}"
        die(msg)
    return path


def find_binary_candidate(build_type: str = "release") -> Optional[Path]:
    """Search for the cdin binary in typical build output directories."""
    for candidate in build_output_candidates(build_type):
        if candidate.is_file():
            return candidate
    return None


def find_installed_binary() -> Optional[Path]:
    """Find cdin binary that is already installed on the system."""
    prefix_bin = default_prefix() / "bin" / EXE_NAME
    candidates = [
        shutil.which("cdin"),
        str(prefix_bin),
        str(Path.home() / ".local" / "bin" / "cdin"),
        "/usr/local/bin/cdin",
        "/usr/bin/cdin",
    ]
    for c in candidates:
        if c and Path(c).is_file():
            return Path(c)
    return None


def current_installed_version(binary: Path) -> str:
    try:
        result = subprocess.run(
            [str(binary), "--version"],
            capture_output=True, text=True, timeout=5,
        )
        m = re.search(r"(\d+\.\d+\.\d+)", result.stdout + result.stderr)
        return m.group(1) if m else "unknown"
    except Exception:
        return "unknown"


def version_gt(a: str, b: str) -> bool:
    """Return True if version a > b (simple semver compare)."""
    def parts(v):
        return [int(x) for x in re.findall(r"\d+", v)]
    try:
        return parts(a) > parts(b)
    except Exception:
        return a != b


def find_data_dir() -> Optional[Path]:
    """The ASSEMBLED data/ to install next to a binary.

    Never the source tree. The source data/ holds only the runtime core; the
    fonts, the default theme and the mandatory plugins arrive from cdin-x at
    build time and live in build/<platform>-<build>/data. Copying the source
    would install an editor with no fonts and no theme, which fails at
    startup rather than at install time — the worst place to find out.
    """
    for candidate in (ROOT_DIR / "bin" / "data", ROOT_DIR / "data"):
        if not candidate.is_dir():
            continue
        # A build output is recognisable by its bundle index. The source tree
        # has core/ and nothing else, so this is also what stops the two
        # being confused.
        if (candidate / "BUNDLE.lua").is_file():
            return candidate
    # No bundle index: fall back to a build output that exists, then to
    # whatever looks most like a usable data directory.
    for pattern in ("build/*/data", "build/*-*/data"):
        for candidate in sorted(ROOT_DIR.glob(pattern)):
            if (candidate / "core").is_dir():
                return candidate
    return None


def find_icons_src() -> Optional[Path]:
    from ._constants import SCRIPT_DIR
    for candidate in (SCRIPT_DIR / "icons", ROOT_DIR / "icons", ROOT_DIR / "bin" / "icons"):
        if candidate.is_dir():
            return candidate
    return None


def copytree_force(src: Path, dst: Path) -> None:
    """Copy tree, overwriting existing files."""
    dst.mkdir(parents=True, exist_ok=True)
    for item in src.rglob("*"):
        rel  = item.relative_to(src)
        dest = dst / rel
        if item.is_dir():
            dest.mkdir(parents=True, exist_ok=True)
        else:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, dest)


def install_binary(src: Path, dest: Path) -> None:
    """Copy a binary to dest and make it executable."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    dest.chmod(dest.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    ok(f"Installed binary → {dest}")


def install_data(dest_bin_dir: Path) -> None:
    """Copy the data/ directory next to the installed binary (if found)."""
    src_data = find_data_dir()
    if src_data:
        data_dst = dest_bin_dir / "data"
        data_dst.mkdir(parents=True, exist_ok=True)
        copytree_force(src_data, data_dst)
        ok(f"Installed data   → {data_dst}")


def extract_archive(archive: Path, dest: Path) -> None:
    """Extract a .tar.gz or .zip archive into dest/."""
    dest.mkdir(parents=True, exist_ok=True)
    name = archive.name
    if name.endswith(".tar.gz") or name.endswith(".tgz"):
        with tarfile.open(archive) as tf:
            tf.extractall(dest)
    elif archive.suffix == ".zip":
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(dest)
    else:
        raise ValueError(f"Unsupported archive format: {archive}")


def replace_binary_from_archive(archive: Path, tmp: Path, cdin_bin: Path) -> None:
    """
    Extract archive, find the cdin binary inside, replace the installed one,
    and update data files if present.
    """
    extract_dir = tmp / "extracted"

    # Bare binary (no archive container)
    if archive.suffix not in (".gz", ".tgz", ".zip") and not str(archive).endswith(".tar.gz"):
        install_binary(archive, cdin_bin)
        return

    extract_archive(archive, extract_dir)

    new_bin = next(extract_dir.rglob(EXE_NAME), None)
    if not new_bin:
        die(f"cdin binary not found in archive.")

    install_binary(new_bin, cdin_bin)

    data_src = next(extract_dir.rglob("data"), None)
    if data_src and data_src.is_dir():
        data_dst = cdin_bin.parent / "data"
        data_dst.mkdir(exist_ok=True)
        copytree_force(data_src, data_dst)
        ok("Updated data files")
