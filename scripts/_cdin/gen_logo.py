from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path
from typing import Optional

from .ui import banner, info, ok, die


DEFAULT_GRID   = 64
LOGO_LUA_PATH  = Path("data") / "core" / "rootview" / "logo.lua"

def _require(pkg: str, pip_name: Optional[str] = None):
    try:
        return __import__(pkg)
    except ImportError:
        die(f"Missing dependency: pip install {pip_name or pkg}")

def rasterize(svg_path: Path, grid: int):
    cairosvg = _require("cairosvg")
    np       = _require("numpy")
    Image    = _require("PIL.Image", "Pillow").Image

    png = cairosvg.svg2png(url=str(svg_path), output_width=grid, output_height=grid)
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    return np.array(img)

def build_spans(pixels, grid: int) -> list:
    """Collapse same-colour runs per row → (row, col, width, r, g, b) tuples."""
    spans = []
    for row in range(grid):
        run_col = run_r = run_g = run_b = None
        for col in range(grid):
            r, g, b, a = (int(x) for x in pixels[row, col])
            visible = a > 16
            if visible and run_col is None:
                run_col, run_r, run_g, run_b = col, r, g, b
            elif run_col is not None:
                if not visible or r != run_r or g != run_g or b != run_b:
                    spans.append((row, run_col, col - run_col, run_r, run_g, run_b))
                    run_col, run_r, run_g, run_b = (col, r, g, b) if visible else (None,) * 4
        if run_col is not None:
            spans.append((row, run_col, grid - run_col, run_r, run_g, run_b))
    return spans

def emit_lua(spans: list, grid: int, svg_path: Path, out: Optional[Path]) -> None:
    rel = svg_path.name
    lines = [
        "-- logo.lua — cdin logo watermark data",
        "--",
        f"-- AUTO-GENERATED from {rel}.  Do not edit.",
        "-- To regenerate:",
        f"--   python3 scripts/cdin.py gen-logo",
        "--",
        "-- Each span: { row, col, width, r, g, b }",
        f"-- Fits a {grid}×{grid} grid; draw_watermark() scales it to the viewport.",
        "",
        "local M = {}",
        "",
        f"M.GRID = {grid}",
        "",
        "M.SPANS = {",
    ]
    for row, col, w, r, g, b in spans:
        lines.append(f"  {{{row},{col},{w},{r},{g},{b}}},")
    lines += [
        "}",
        "",
        "--- Draw the logo as a faint watermark centred in the given viewport.",
        "-- @param vx     left edge of viewport (pixels)",
        "-- @param vy     top  edge of viewport (pixels)",
        "-- @param vw     width  of viewport (pixels)",
        "-- @param vh     height of viewport (pixels)",
        "-- @param alpha  transparency override (default 28, range 0-255)",
        "function M.draw_watermark(vx, vy, vw, vh, alpha)",
        "  local GRID = M.GRID",
        "  local px   = math.max(2, math.floor(math.min(vw, vh) * 0.55 / GRID))",
        "  local lw   = GRID * px",
        "  local lh   = GRID * px",
        "  local ox   = vx + math.floor((vw - lw) / 2)",
        "  local oy   = vy + math.floor((vh - lh) / 2)",
        "  local a    = alpha or 28",
        "",
        "  for _, s in ipairs(M.SPANS) do",
        "    local sy, sx, sw, r, g, b = s[1], s[2], s[3], s[4], s[5], s[6]",
        "    renderer.draw_rect(ox + sx * px, oy + sy * px, sw * px, px,",
        "                       {r, g, b, a})",
        "  end",
        "end",
        "",
        "return M",
        "",
    ]
    text = "\n".join(lines)
    if out:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)

def cmd_gen_logo(args: argparse.Namespace) -> None:
    banner("GEN LOGO")

    from ._constants import ROOT_DIR
    svg  = Path(args.svg) if getattr(args, "svg", None) else ROOT_DIR / "scripts" / "icon.svg"
    grid = getattr(args, "grid", DEFAULT_GRID) or DEFAULT_GRID
    out  = Path(args.out) if getattr(args, "out", None) else ROOT_DIR / LOGO_LUA_PATH

    if not svg.is_file():
        die(f"SVG not found: {svg}")

    info(f"Source : {svg}")
    info(f"Grid   : {grid}×{grid}")
    info(f"Out    : {out or 'stdout'}")

    pixels = rasterize(svg, grid)
    spans  = build_spans(pixels, grid)
    emit_lua(spans, grid, svg, out)

    ok(f"gen-logo done — {len(spans)} spans written.")