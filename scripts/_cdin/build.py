from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

from ._constants import ROOT_DIR, ICON_SVG, ICON_INL
from .platform import PLATFORM, default_jobs, default_prefix
from .ui import banner, info, ok, warn, die
from .utils import run, find_binary_candidate, copytree_force


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

    _sync_data_windows(build_type)

    binary = find_binary_candidate(build_type)
    if binary:
        ok(f"Build complete.  Binary: {binary.relative_to(ROOT_DIR)}")
    else:
        ok("Build complete.")


def _sync_data_windows(build_type: str) -> None:
    """Windows-only: ensure the data/ directory inside the build output is current.

    The Makefile creates a symlink/junction from build/<platform>-<type>/data to
    the project-root data/ directory, but only once (guarded by `[ ! -e ... ]`).
    If that first attempt produced an empty directory instead of a working
    junction (common when developer-mode symlinks are unavailable), all future
    builds silently use the stale copy.  We detect this and force a sync.
    """
    if PLATFORM != "windows":
        return

    src_data = ROOT_DIR / "data"
    if not src_data.is_dir():
        return

    build_out = ROOT_DIR / "build" / f"windows-{build_type}"
    if not build_out.is_dir():
        return

    data_link = build_out / "data"

    try:
        if data_link.resolve() == src_data.resolve():
            return
    except Exception:
        pass

    copytree_force(src_data, data_link)
    ok(f"Synced data/ → {data_link.relative_to(ROOT_DIR)}")


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