local T = require "harness"
local text = require "core.text"
local u8 = require "core.text.utf8"

-- ── module surface ──────────────────────────────────────────────────
T.eq(type(text.visual), "function", "text.visual exists")
T.ok(text.utf8 and text.bidi and text.shaper, "submodules exposed")

-- ── helpers ─────────────────────────────────────────────────────────

local function cps(s)
  local out, pos = {}, 1
  while pos <= #s do
    local cp, nxt = u8.decode(s, pos)
    if not cp or nxt == pos then break end
    out[#out + 1] = cp
    pos = nxt
  end
  return out
end

local function has_presentation(s)
  local pos = 1
  while pos <= #s do
    local cp, nxt = u8.decode(s, pos)
    if not cp or nxt == pos then break end
    if cp >= 0xFB50 and cp <= 0xFEFF then return true end
    pos = nxt
  end
  return false
end

-- ── pure LTR ────────────────────────────────────────────────────────
T.eq(text.visual("hello", {}), "hello", "ascii passthrough with empty opts")
T.eq(text.visual("hello"), "hello", "ascii passthrough, no opts")
T.eq(text.visual("hello", { direction = "ltr" }), "hello",
  "forced ltr short-circuits when no rtl present")
T.eq(text.visual(nil), "", "nil-safe visual")

-- ── pure RTL: shaped AND reordered ──────────────────────────────────
local out = text.visual("سلام")
T.ok(has_presentation(out), "presentation forms present after shaping")
T.eq(cps(out), { 0xFEE1, 0xFEFC, 0xFEB3 },
  "RTL-reversed shaped run; first glyph is shaped م (logical last letter)")

-- ── shaping can be switched off ─────────────────────────────────────
local unshaped = text.visual("سلام", { shaping = false })
T.ok(not has_presentation(unshaped), "no presentation forms when shaping=false")
T.eq(unshaped, "مالس", "bidi reorder still applied when shaping=false")

-- ── direction option ────────────────────────────────────────────────
T.eq(text.visual("abc سلام", { direction = "ltr", shaping = false }),
  "abc مالس",
  "forced ltr keeps run order, mirrors the rtl run in place")
T.eq(text.visual("abc سلام", { direction = "rtl", shaping = false }),
  "مالسabc ",
  "forced rtl reverses run order")
T.eq(text.visual("abc سلام def", { shaping = false }), "abc  مالسdef",
  "auto base dir picks ltr from first strong char")
