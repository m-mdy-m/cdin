#!/usr/bin/env python3
"""
Usage:
    python3 scripts/gen_logo_lua.py icon.svg > data/core/rootview/logo.lua
    python3 scripts/gen_logo_lua.py icon.svg --out data/core/rootview/logo.lua
"""

import sys
import io
import os
import argparse
import datetime

def main():
    parser = argparse.ArgumentParser(description="Convert icon.svg → logo.lua")
    parser.add_argument("svg", help="Path to icon.svg")
    parser.add_argument("--out", "-o", help="Output path (default: stdout)")
    parser.add_argument("--grid", type=int, default=64,
                        help="Grid size in pixels (default: 64)")
    parser.add_argument("--alpha-threshold", type=int, default=16,
                        help="Minimum alpha to consider a pixel visible (default: 16)")
    parser.add_argument("--merge-tolerance", type=int, default=8,
                        help="Max per-channel colour difference to merge into one span (default: 8)")
    args = parser.parse_args()

    try:
        import cairosvg
    except ImportError:
        sys.exit("ERROR: cairosvg not found. Install with: pip install cairosvg pillow")

    try:
        from PIL import Image
    except ImportError:
        sys.exit("ERROR: Pillow not found. Install with: pip install pillow")

    grid = args.grid
    png_bytes = cairosvg.svg2png(url=args.svg, output_width=grid, output_height=grid)
    img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    pixels = img.load()

    threshold = args.alpha_threshold
    tol       = args.merge_tolerance
    spans     = []

    for row in range(grid):
        col = 0
        while col < grid:
            r, g, b, a = pixels[col, row]
            if a < threshold:
                col += 1
                continue
            start = col
            span_r, span_g, span_b = r, g, b
            col += 1
            while col < grid:
                nr, ng, nb, na = pixels[col, row]
                if na < threshold:
                    break
                if (abs(nr - span_r) <= tol and
                    abs(ng - span_g) <= tol and
                    abs(nb - span_b) <= tol):
                    length = col - start
                    span_r = (span_r * length + nr) // (length + 1)
                    span_g = (span_g * length + ng) // (length + 1)
                    span_b = (span_b * length + nb) // (length + 1)
                    col += 1
                else:
                    break
            width = col - start
            spans.append((row, start, width, span_r, span_g, span_b))

    svg_basename = os.path.basename(args.svg)
    now          = datetime.datetime.now().strftime("%Y-%m-%d")

    lines = []
    lines.append("-- logo.lua — cdin logo watermark data")
    lines.append(f"-- AUTO-GENERATED on {now} from {svg_basename} (grid={grid})")
    lines.append("--")
    lines.append("-- To regenerate:")
    lines.append(f"--   python3 scripts/gen_logo_lua.py {svg_basename} --out data/core/rootview/logo.lua")
    lines.append("")
    lines.append("local M = {}")
    lines.append("")
    lines.append(f"M.GRID = {grid}")
    lines.append("")
    lines.append("-- { row, col, width, r, g, b }")
    lines.append("M.SPANS = {")
    for s in spans:
        lines.append("  {{{},{},{},{},{},{}}},".format(*s))
    lines.append("}")
    lines.append("")
    lines.append("--- Draw the logo as a faint watermark centred in the given viewport.")
    lines.append("-- @param vx   left edge of viewport (pixels)")
    lines.append("-- @param vy   top  edge of viewport (pixels)")
    lines.append("-- @param vw   width  of viewport (pixels)")
    lines.append("-- @param vh   height of viewport (pixels)")
    lines.append("-- @param alpha  optional alpha override (default 28, range 0-255)")
    lines.append("function M.draw_watermark(vx, vy, vw, vh, alpha)")
    lines.append(f"  local GRID  = M.GRID")
    lines.append("  local px    = math.max(2, math.floor(math.min(vw, vh) * 0.55 / GRID))")
    lines.append("  local lw    = GRID * px")
    lines.append("  local lh    = GRID * px")
    lines.append("  local ox    = vx + math.floor((vw - lw) / 2)")
    lines.append("  local oy    = vy + math.floor((vh - lh) / 2)")
    lines.append("  local a     = alpha or 28")
    lines.append("")
    lines.append("  for _, s in ipairs(M.SPANS) do")
    lines.append("    local sy, sx, sw, r, g, b = s[1], s[2], s[3], s[4], s[5], s[6]")
    lines.append("    renderer.draw_rect(ox + sx * px, oy + sy * px, sw * px, px,")
    lines.append("                       {r, g, b, a})")
    lines.append("  end")
    lines.append("end")
    lines.append("")
    lines.append("return M")

    output = "\n".join(lines) + "\n"

    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(output)
        print(f"Written {len(spans)} spans to {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(output)
        print(f"-- {len(spans)} spans total", file=sys.stderr)


if __name__ == "__main__":
    main()

