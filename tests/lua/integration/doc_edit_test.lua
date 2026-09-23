local T = require "harness"

local clock = 0
T.stub("system", {
  get_time = function()
    clock = clock + 1
    return clock
  end,
  get_file_info = function() return nil end,
  fuzzy_match = function() return nil end,
  list_dir = function() return {} end,
})

package.loaded["core"] = { add_thread = function() end, threads = {} }
T.teardown(function() package.loaded["core"] = nil end)

local u8 = require "core.text.utf8"
local ok, Doc = pcall(require, "core.doc")
T.ok(ok, "core.doc loads with light stubs" .. (ok and "" or (": " .. tostring(Doc))))

if ok then
  -- full text of the doc (get_text needs explicit positions)
  local function full_text(d)
    return d:get_text(1, 1, #d.lines, #d.lines[#d.lines])
  end

  -- ── fresh doc ─────────────────────────────────────────────────────
  local doc = Doc()
  T.eq(#doc.lines, 1, "fresh doc has one line")
  T.eq(doc.lines[1], "\n", "fresh line is just a newline")
  T.eq(full_text(doc), "", "fresh doc text is empty")
  T.eq(doc:get_name(), "unsaved", "unsaved doc name")
  T.eq(doc:is_dirty(), false, "fresh doc is clean")
  T.eq(doc.has_selection and doc:has_selection(), false, "no selection initially")

  -- ── insert ascii + persian ────────────────────────────────────────
  doc:insert(1, 1, "hello")
  T.eq(doc.lines[1], "hello\n", "ascii insert")
  T.eq(full_text(doc), "hello", "get_text after ascii insert")
  T.eq(doc:is_dirty(), true, "insert marks doc dirty")

  doc:insert(1, 6, " سلام")
  T.eq(doc.lines[1], "hello سلام\n", "persian insert at line end")
  T.eq(full_text(doc), "hello سلام", "get_text keeps persian bytes")
  T.eq(u8.len(full_text(doc)), 10, "utf8 length: 5 latin + 1 space + 4 persian")

  -- ── undo / redo (public API, no scheduler needed) ─────────────────
  doc:undo()
  T.eq(full_text(doc), "hello", "undo removes the last insert")
  doc:undo()
  T.eq(full_text(doc), "", "second undo removes the first insert")
  T.eq(doc.lines[1], "\n", "back to a single empty line")
  doc:redo()
  T.eq(full_text(doc), "hello", "redo restores the first insert")
  doc:redo()
  T.eq(full_text(doc), "hello سلام", "second redo restores the persian insert")

  -- ── remove + undo ─────────────────────────────────────────────────
  doc:remove(1, 1, 1, 6)
  T.eq(doc.lines[1], " سلام\n", "remove drops 'hello'")
  T.eq(full_text(doc), " سلام", "get_text after remove")
  doc:undo()
  T.eq(full_text(doc), "hello سلام", "undo restores removed text")
  T.eq(doc.lines[1], "hello سلام\n", "line restored byte-exact")

  -- ── multi-line insert ─────────────────────────────────────────────
  doc:insert(1, 1, "line1\nline2")
  T.eq(#doc.lines, 2, "newline in inserted text splits the line")
  T.eq(doc.lines[1], "line1\n", "first split line")
  T.eq(doc.lines[2], "line2hello سلام\n", "second split line keeps the tail")
  T.eq(full_text(doc), "line1\nline2hello سلام",
    "get_text across two lines")

  -- ── selection helpers used by editing commands ────────────────────
  doc:set_selection(1, 1, 1, 6)
  T.eq(doc:has_selection(), true, "set_selection creates a selection")
  local l1, c1, l2, c2 = doc:get_selection(true)
  T.eq({ l1, c1, l2, c2 }, { 1, 1, 1, 6 }, "sorted selection round-trips")
  T.eq(doc:get_text(l1, c1, l2, c2), "line1", "selected text is 'line1'")
end
