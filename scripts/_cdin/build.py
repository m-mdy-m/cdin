from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from ._constants import ROOT_DIR, ICON_SVG, ICON_INL, GEN_ICON_PY
from .platform import PLATFORM, default_jobs, default_prefix
from .ui import banner, info, ok, warn, die
from .utils import run, find_binary_candidate


def cmd_build(args: argparse.Namespace) -> None:
    banner("BUILD")

    build_type = "debug" if getattr(args, "debug", False) else "release"
    jobs       = getattr(args, "jobs", None) or default_jobs()
    prefix     = Path(getattr(args, "prefix", None) or default_prefix())

    info(f"Platform   : {PLATFORM}")
    info(f"Build type : {build_type}")
    info(f"Jobs       : {jobs}")
    info(f"Prefix     : {prefix}")

    _regenerate_icon()
    make_cmd = _find_make()

    make_flags = [
        f"-j{jobs}",
        f"BUILD_TYPE={build_type}",
        f"PREFIX={prefix}",
        f"PLATFORM={PLATFORM}",
    ]

    info(f"Running {make_cmd} {' '.join(make_flags)} …")
    try:
        run([make_cmd, "build"] + make_flags)
    except subprocess.CalledProcessError:
        die("Build failed. Check the output above for errors.")

    binary = find_binary_candidate(build_type)
    if binary:
        ok(f"Build complete.  Binary: {binary.relative_to(ROOT_DIR)}")
    else:
        ok("Build complete.")

def _regenerate_icon() -> None:
    if not ICON_SVG.is_file():
        warn(f"{ICON_SVG} not found — icon.inl will not be regenerated.")
        return

    info(f"Regenerating {ICON_INL.relative_to(ROOT_DIR)} (always fresh) …")
    try:
        run([sys.executable, str(GEN_ICON_PY), "--svg", str(ICON_SVG), "--out", str(ICON_INL)])
        ok(f"{ICON_INL.name} generated.")
    except subprocess.CalledProcessError:
        warn("gen_icon.py failed — icon.inl may be stale.")


def _find_make() -> str:
    for candidate in ("make", "mingw32-make", "gmake"):
        if shutil.which(candidate):
            return candidate
    die("No 'make' found. Install build tools first.")
