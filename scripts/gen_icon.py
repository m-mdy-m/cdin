#!/usr/bin/env python3
"""
Usage:
    python3 scripts/gen_icon.py [--size 64] [--out icon.inl] [--preview icon.png]

Requires: cairosvg  (pip install cairosvg)
The SVG source is scripts/icon.svg (same directory as this script).
"""
import argparse, struct, zlib, sys
from pathlib import Path


def parse_png_rgba(data: bytes) -> tuple:
    """Decode a PNG to raw RGBA bytes without Pillow."""
    assert data[:8] == b'\x89PNG\r\n\x1a\n', "not a PNG"
    pos = 8; width = height = 0; idat = []
    color_type = bit_depth = 0
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos+4])[0]
        tag    = data[pos+4:pos+8]
        chunk  = data[pos+8:pos+8+length]
        if tag == b'IHDR':
            width, height = struct.unpack('>II', chunk[:8])
            bit_depth, color_type = chunk[8], chunk[9]
        elif tag == b'IDAT':
            idat.append(chunk)
        pos += 12 + length

    channels = {0:1, 2:3, 3:1, 4:2, 6:4}.get(color_type, 3)
    stride   = width * channels
    raw      = zlib.decompress(b''.join(idat))
    out      = bytearray()
    idx      = 0
    prev     = bytearray(stride)

    for _ in range(height):
        ftype = raw[idx]; idx += 1
        row   = bytearray(raw[idx:idx+stride]); idx += stride

        def paeth(a, b, c):
            p = a+b-c; pa=abs(p-a); pb=abs(p-b); pc=abs(p-c)
            return a if pa<=pb and pa<=pc else (b if pb<=pc else c)

        if ftype == 1:
            for x in range(channels, stride): row[x] = (row[x] + row[x-channels]) & 0xff
        elif ftype == 2:
            for x in range(stride):           row[x] = (row[x] + prev[x]) & 0xff
        elif ftype == 3:
            for x in range(stride):
                a = row[x-channels] if x >= channels else 0
                row[x] = (row[x] + (a + prev[x]) // 2) & 0xff
        elif ftype == 4:
            for x in range(stride):
                a = row[x-channels]        if x >= channels else 0
                c = prev[x-channels]       if x >= channels else 0
                row[x] = (row[x] + paeth(a, prev[x], c)) & 0xff

        if channels == 3:
            for x in range(width):
                out.extend([row[x*3], row[x*3+1], row[x*3+2], 255])
        else:
            out.extend(row)
        prev = row

    return width, height, bytes(out)


def write_icon_inl(pixels: bytes, w: int, h: int, out_path: Path):
    lines = [
        "/* Auto-generated from scripts/icon.svg — do not hand-edit.",
        f" * Size: {w}x{h} RGBA (R,G,B,A byte order, row-major, top-to-bottom).",
        " * Re-generate: python3 scripts/gen_icon.py */",
        "static const unsigned char icon_rgba[] = {",
    ]
    for i in range(0, len(pixels), 16):
        lines.append("  " + ", ".join(str(b) for b in pixels[i:i+16]) + ",")
    lines += [
        "};",
        f"static const unsigned icon_rgba_len    = {len(pixels)};",
        f"static const unsigned icon_rgba_width  = {w};",
        f"static const unsigned icon_rgba_height = {h};",
        "",
    ]
    out_path.write_text("\n".join(lines))


def main():
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("--size",    type=int, default=64)
    ap.add_argument("--out",     default=None)
    ap.add_argument("--preview", default=None)
    args = ap.parse_args()

    try:
        import cairosvg
    except ImportError:
        sys.exit("Error: cairosvg not installed.  Run: pip install cairosvg")

    repo_root  = Path(__file__).resolve().parent.parent
    svg_path   = Path(__file__).resolve().parent / "icon.svg"
    out_path   = Path(args.out) if args.out else repo_root / "icon.inl"

    if not svg_path.exists():
        sys.exit(f"Error: SVG source not found at {svg_path}")

    svg_data = svg_path.read_bytes()
    png_data = cairosvg.svg2png(bytestring=svg_data,
                                output_width=args.size,
                                output_height=args.size)

    w, h, pixels = parse_png_rgba(png_data)
    write_icon_inl(pixels, w, h, out_path)
    print(f"wrote {out_path}  ({w}x{h}, {len(pixels)} bytes)")

    if args.preview:
        Path(args.preview).write_bytes(png_data)
        print(f"wrote preview {args.preview}")


if __name__ == "__main__":
    main()
