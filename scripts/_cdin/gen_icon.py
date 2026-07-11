"""
Produces:
    icon.ico             Windows  (16, 32, 48, 256 px)
    icon.icns            macOS    (16 … 512 px via iconutil or manual ICNS build)
    icon-NNNxNNN.png     individual PNGs in the output directory
    <file>.inl           C inline array (for embedding icon in the binary)

Requires: cairosvg, Pillow
"""

from __future__ import annotations

import argparse
import io
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

from .ui import banner, info, ok, warn, die


ICON_SIZES = [16, 32, 48, 128, 256, 512]
ICO_SIZES  = [16, 32, 48, 256]
ICNS_MAP   = {
    16:  b"icp4",
    32:  b"ic11",
    128: b"ic07",
    256: b"ic13",
    512: b"ic14",
}

def _require(pkg: str, pip_name: Optional[str] = None):
    try:
        return __import__(pkg)
    except ImportError:
        die(f"Missing dependency: pip install {pip_name or pkg}")

def rasterize_png(svg_path: Path, size: int, out_dir: Optional[Path] = None) -> bytes:
    # 1. Pre-rendered PNG on disk (rsvg-convert step in CI)
    if out_dir is not None:
        for stem in (f"cdin-{size}", f"icon-{size}x{size}"):
            candidate = out_dir / f"{stem}.png"
            if candidate.is_file():
                return candidate.read_bytes()

    # 2. rsvg-convert available on PATH
    try:
        result = subprocess.run(
            ["rsvg-convert", "-w", str(size), "-h", str(size), str(svg_path)],
            capture_output=True,
        )
        if result.returncode == 0 and result.stdout:
            return result.stdout
    except FileNotFoundError:
        pass  # rsvg-convert not installed – fall through

    # 3. cairosvg (Python package)
    try:
        import cairosvg as _cairosvg  # type: ignore
        return _cairosvg.svg2png(url=str(svg_path),
                                 output_width=size, output_height=size)
    except ImportError:
        die("Missing dependency: pip install cairosvg")


def open_image(png_bytes: bytes):
    Image = _require("PIL.Image", "Pillow").Image
    return Image.open(io.BytesIO(png_bytes)).convert("RGBA")


def _png_bytes(img) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def write_png(img, path: Path) -> None:
    with open(path, "wb") as f:
        f.write(_png_bytes(img))

def build_ico(images: dict, path: Path) -> None:
    sizes = sorted(images.keys())
    pngs  = {s: _png_bytes(images[s]) for s in sizes}

    header_size = 6 + 16 * len(sizes)
    offset = header_size
    offsets = []
    for s in sizes:
        offsets.append(offset)
        offset += len(pngs[s])

    with open(path, "wb") as f:
        f.write(struct.pack("<HHH", 0, 1, len(sizes)))
        for i, s in enumerate(sizes):
            w = h = 0 if s >= 256 else s
            f.write(struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(pngs[s]), offsets[i]))
        for s in sizes:
            f.write(pngs[s])

def build_icns(images: dict, path: Path) -> None:
    if sys.platform == "darwin":
        if _build_icns_iconutil(images, path):
            return
    _build_icns_manual(images, path)


def _build_icns_iconutil(images: dict, path: Path) -> bool:
    name_map = {
        16: "icon_16x16.png",    32:  "icon_16x16@2x.png",
        64: "icon_32x32@2x.png", 128: "icon_128x128.png",
        256: "icon_128x128@2x.png", 512: "icon_256x256@2x.png",
    }
    iconset = Path(tempfile.mkdtemp(suffix=".iconset"))
    try:
        for s, img in images.items():
            if s in name_map:
                write_png(img, iconset / name_map[s])
        result = subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(path)],
            capture_output=True,
        )
        return result.returncode == 0
    finally:
        import shutil
        shutil.rmtree(iconset, ignore_errors=True)


def _build_icns_manual(images: dict, path: Path) -> None:
    chunks = []
    for s in sorted(images.keys()):
        if s not in ICNS_MAP:
            continue
        data = _png_bytes(images[s])
        ostype = ICNS_MAP[s]
        chunks.append(ostype + struct.pack(">I", len(data) + 8) + data)
    body = b"".join(chunks)
    with open(path, "wb") as f:
        f.write(b"icns" + struct.pack(">I", len(body) + 8) + body)

def build_inl(images: dict, path: Path) -> None:
    size = max(images.keys())
    data = _png_bytes(images[size])
    with open(path, "w", encoding="utf-8") as f:
        f.write("/* AUTO-GENERATED — do not edit. Regenerate with gen-icon. */\n")
        f.write(f"static const unsigned char icon_data[] = {{\n")
        for i, byte in enumerate(data):
            if i % 16 == 0:
                f.write("  ")
            f.write(f"0x{byte:02x},")
            f.write("\n" if i % 16 == 15 else " ")
        f.write("\n};\n")
        f.write(f"static const unsigned int icon_data_len = {len(data)};\n")

def cmd_gen_icon(args: argparse.Namespace) -> None:
    banner("GEN ICON")

    svg     = Path(args.svg)
    out_dir = Path(args.out_dir) if getattr(args, "out_dir", None) else svg.parent
    out_ico = Path(args.out_ico) if getattr(args, "out_ico", None) else None
    out_inl = Path(args.out_inl) if getattr(args, "out_inl", None) else None

    if not svg.is_file():
        die(f"SVG not found: {svg}")

    out_dir.mkdir(parents=True, exist_ok=True)
    info(f"Source  : {svg}")
    info(f"Out dir : {out_dir}")

    images: dict = {}
    for size in ICON_SIZES:
        png   = rasterize_png(svg, size, out_dir)
        img   = open_image(png)
        images[size] = img
        dest  = out_dir / f"icon-{size}x{size}.png"
        write_png(img, dest)
        ok(f"  {dest.name}")

    ico_path = out_ico or out_dir / "icon.ico"
    build_ico({s: images[s] for s in ICO_SIZES if s in images}, ico_path)
    ok(f"  {ico_path.name}")

    icns_path = out_dir / "icon.icns"
    build_icns(images, icns_path)
    ok(f"  {icns_path.name}")

    if out_inl:
        build_inl(images, out_inl)
        ok(f"  {out_inl.name}")

    ok("gen-icon done.")