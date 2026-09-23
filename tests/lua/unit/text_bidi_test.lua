local T = require "harness"
local bidi = require "core.text.bidi"

-- ── is_rtl_char ─────────────────────────────────────────────────────
T.ok(bidi.is_rtl_char(0x0633), "arabic seen is rtl")
T.ok(bidi.is_rtl_char(0x062E), "arabic kha is rtl")
T.ok(bidi.is_rtl_char(0x05E9), "hebrew shin is rtl")
T.ok(not bidi.is_rtl_char(0x61), "'a' is not rtl")
T.ok(not bidi.is_rtl_char(0x31), "'1' (EN) is not rtl")
T.ok(not bidi.is_rtl_char(0x20), "space (WS) is not rtl")

-- ── base_dir: first strong char wins, default ltr ───────────────────
T.eq(bidi.base_dir("hello"), "ltr", "latin base ltr")
T.eq(bidi.base_dir("سلام"), "rtl", "persian base rtl")
T.eq(bidi.base_dir("abc سلام def"), "ltr", "first strong char wins")
T.eq(bidi.base_dir("سلام abc"), "rtl", "rtl first strong wins")
T.eq(bidi.base_dir("123"), "ltr", "digits are neutral, default ltr")
T.eq(bidi.base_dir("  سلام"), "rtl", "leading spaces skipped")
T.eq(bidi.base_dir("שלום"), "rtl", "hebrew base rtl")
T.eq(bidi.base_dir(""), "ltr", "empty defaults ltr")
T.eq(bidi.base_dir(nil), "ltr", "nil-safe base_dir")

-- ── has_rtl ─────────────────────────────────────────────────────────
T.ok(bidi.has_rtl("سلام"), "persian detected")
T.ok(bidi.has_rtl("abc سلام def"), "mixed detected")
T.ok(bidi.has_rtl("שלום"), "hebrew detected")
T.ok(not bidi.has_rtl("hello"), "latin has no rtl")
T.ok(not bidi.has_rtl("123 !"), "digits/punct have no rtl")
T.ok(not bidi.has_rtl(""), "empty has no rtl")
T.ok(not bidi.has_rtl(nil), "nil-safe has_rtl")

-- ── visual: logical -> visual order ─────────────────────────────────
T.eq(bidi.visual("hello"), "hello", "pure ltr passthrough")
T.eq(bidi.visual("سلام"), "مالس", "single rtl run reversed char-wise")
T.eq(bidi.visual("שלום"), "םולש", "hebrew run reversed char-wise")
T.eq(bidi.visual("ab سلام"), "ab مالس",
  "ltr base: rtl run mirrored in place, run order kept")
T.eq(bidi.visual("abc سلام def"), "abc  مالسdef",
  "ltr base: both latin runs untouched, rtl run mirrored")
T.eq(bidi.visual("abc سلام", "rtl"), "مالسabc ",
  "rtl base: run order reversed, rtl run mirrored")
T.eq(bidi.visual("hello", "ltr"), "hello", "forced ltr passthrough")
T.eq(bidi.visual("123", "auto"), "123", "neutral-only line")
T.eq(bidi.visual(""), "", "empty string")
T.eq(bidi.visual(nil), "", "nil-safe visual")
