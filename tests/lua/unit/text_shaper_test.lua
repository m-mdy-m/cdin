local T = require "harness"
local shaper = require "core.text.shaper"
local u8 = require "core.text.utf8"

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

T.ok(shaper.needs_shaping("سلام"), "persian needs shaping")
T.ok(shaper.needs_shaping("خ"), "single FORMS char needs shaping")
T.ok(not shaper.needs_shaping("hello"), "latin does not")
T.ok(not shaper.needs_shaping(""), "empty does not")
T.ok(not shaper.needs_shaping(nil), "nil-safe needs_shaping")
T.ok(not shaper.needs_shaping("abc 123"), "ascii+digits do not")

T.eq(shaper.shape("hello"), "hello", "latin untouched")
T.eq(shaper.shape(""), "", "empty untouched")
T.eq(shaper.shape(nil), "", "nil-safe shape")

T.eq(cps(shaper.shape("س")), { 0xFEB1 }, "lone seen -> isolated FEB1")

T.eq(cps(shaper.shape("سلام")), { 0xFEB3, 0xFEFC, 0xFEE1 },
  "initial seen + final lam-alef ligature + isolated mim")

T.eq(cps(shaper.shape("ببب")), { 0xFE91, 0xFE92, 0xFE90 },
  "beh chain picks initial/medial/final forms")

T.eq(cps(shaper.shape("با")), { 0xFE91, 0xFE8E },
  "beh initial + alef final")
T.eq(cps(shaper.shape("اا")), { 0xFE8D, 0xFE8D },
  "alef never joins forward -> both isolated")

T.eq(cps(shaper.shape("لا")), { 0xFEFB },
  "lam+alef alone -> isolated ligature FEFB")
T.eq(cps(shaper.shape("بلا")), { 0xFE91, 0xFEFC },
  "after a joining letter -> final ligature FEFC")

T.eq(cps(shaper.shape("بَم")), { 0xFE91, 0x064E, 0xFEE2 },
  "fatha between beh and mim: initial beh, mark kept, final mim")

T.eq(cps(shaper.shape("لَا")), { 0xFEDF, 0x064E, 0xFE8E },
  "mark on lam blocks ligature but not joining")

T.eq(cps(shaper.shape("abcخ")), { 0x61, 0x62, 0x63, 0xFEA5 },
  "latin passes through, seen after 'c' stays isolated")
