from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path

from ._constants import ROOT_DIR, ICON_SVG, ICON_INL
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
        f"BUILD={build_type}",
        f"PREFIX={prefix}",
        f"PLATFORM={PLATFORM}",
        f"CDINX_DIR={cdinx_dir()}",
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


def cdinx_dir() -> Path:
    """Where the build looks for the cdin-x checkout.

    CDINX_DIR wins, then the conventional sibling checkout. This is the one
    piece of build glue that knows cdin-x exists; it resolves a path and
    nothing else. When neither is present the make step fails with the
    message that explains what to do about it.
    """
    override = os.environ.get("CDINX_DIR")
    if override:
        return Path(override)
    return ROOT_DIR.parent / "cdin-x"


def _regenerate_icon() -> None:
    if not ICON_SVG.is_file():
        warn(f"{ICON_SVG} not found — icon.inl will not be regenerated.")
        return

    info(f"Regenerating {ICON_INL.relative_to(ROOT_DIR)} …")
    try:
        from .gen_icon import rasterize_png, open_image, build_inl
        import argparse as _ap
        _args = _ap.Namespace(svg=str(ICON_SVG), out_dir=None, out_ico=None, out_inl=str(ICON_INL))
        png = rasterize_png(ICON_SVG, 256)
        img = open_image(png)
        build_inl({256: img}, ICON_INL)
        ok(f"{ICON_INL.name} generated.")
    except Exception as e:
        warn(f"gen_icon failed — icon.inl may be stale. ({e})")


def _find_make() -> str:
    for candidate in ("make", "mingw32-make", "gmake"):
        if shutil.which(candidate):
            return candidate
    die("No 'make' found. Install build tools first.")