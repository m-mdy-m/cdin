local T = require "harness"

-- Runs against the fixture tree scripts/test_lua.lua builds, not against
-- data/themes/ — the bundled theme moved to cdin-x with the rest of the
-- mandatory set, so a theme file the runtime can load is now one an extension
-- registers. The registry is still the runtime's; these are its contracts.
--
-- Environment:
--   CDIN_THEME_TREE  a directory tree holding data/themes/<name>/theme.lua.
--                    It becomes EXEDIR for this test, so the bundled root is
--                    found the way the runtime finds it. The fixtures in
--                    scripts/fixtures/bundled are the tree to point it at.
local TREE = os.getenv("CDIN_THEME_TREE")
if not TREE or TREE == "" then
  T.add_failure("CDIN_THEME_TREE is not set; themes_test.lua needs a tree holding data/themes/")
  return
end

T.stub("renderer", {
  font = {
    load = function(path, size)
      return {
        path = path,
        size = size,
        add_fallback = function() end,
        get_width = function() return 0 end,
        get_height = function() return 10 end,
      }
    end,
  },
  draw_text = function() end,
})
-- themes.lua reads through core.fs, which is the C `fs` module. run.lua
-- supplies it as a preload, so the filesystem here is the real one and TREE
-- has to be a real directory — this test never fabricates a theme file.
T.stub("system", {
  get_time = function() return 0 end,
})

local config = require "core.config"
config.site_dir = TREE

-- The bundled root is EXEDIR/data/themes, and run.lua sets EXEDIR to "." — the
-- source checkout, which has no data/themes/ since the mandatory theme moved to
-- cdin-x. So the bundled root is legitimately empty here, and TREE has to be
-- registered as an extension root instead: that is the same path a real theme
-- takes, through the same add_root, and it is the one worth testing.
rawset(_G, "EXEDIR", TREE)
T.teardown(function() rawset(_G, "EXEDIR", ".") end)
local themes = require "core.themes"

T.eq(themes.add_root(TREE .. "/data/themes"), true,
  "add_root() accepts a directory of themes")

-- ── registry contract ─────────────────────────────────────────────────

T.eq(type(themes.names), "function", "themes.names() exists")
T.eq(type(themes.path), "function", "themes.path() exists")
T.eq(type(themes.load), "function", "themes.load() exists")
T.eq(type(themes.rescan), "function", "themes.rescan() exists")
T.eq(themes.names(), themes.list, "names() returns a copy of list")

local found = false
for _, n in ipairs(themes.names()) do
  if n == "fixture-bundled" then found = true end
end
T.ok(found, "the bundled fixture theme is listed")

-- Compared as a normalized path, not as a string: themes.path builds the path
-- with the platform separator, and a literal "/" here would fail on Windows for
-- no reason other than spelling.
local function norm(p) return (p or ""):gsub("\\", "/"):gsub("/+$", "") end

T.eq(norm(themes.path("fixture-bundled")),
  norm(TREE .. "/data/themes/fixture-bundled/theme.lua"),
  "path() resolves a listed theme")
T.eq(themes.path("no-such-theme"), nil, "path() returns nil for an unknown name")

local loaded, err = themes.load("fixture-bundled")
T.ok(loaded ~= nil, "load() returns the theme: " .. tostring(err))
if loaded then
  T.eq(loaded.name, "fixture-bundled", "the loaded theme self-identifies")
  T.match(loaded.background, "^#%x%x%x%x%x%x$", "theme colors are #rrggbb")
end

local missing, missing_err = themes.load("no-such-theme")
T.ok(missing == nil, "load() returns nil for an unknown name")
T.match(tostring(missing_err), "no such theme", "load() says why it failed")

-- add_root is what makes an extension's themes reachable, so its refusal
-- behaviour is part of the contract: a non-directory must not poison the
-- search order, and adding the same root twice must not duplicate a name.
T.eq(themes.add_root(TREE .. "/data/does-not-exist"), false,
  "add_root() ignores a non-directory")
T.eq(themes.add_root(TREE .. "/data/themes"), true,
  "add_root() on an already-added root is a no-op that reports success")

local seen, dupes = {}, {}
for _, n in ipairs(themes.names()) do
  if seen[n] then dupes[#dupes + 1] = n end
  seen[n] = true
end
T.eq(#dupes, 0, "no theme is listed twice: " .. table.concat(dupes, ", "))

-- ── apply contract ────────────────────────────────────────────────────
--
-- The parts that used to be asserted against data/themes/dracula.lua. What is
-- under test is themes.apply, not the file: the return value, that a failure
-- leaves style alone rather than half-written, and that a later valid apply
-- still works after a failed one.

local function sink()
  return {
    background = { 1, 2, 3 },
    text       = { 4, 5, 6 },
    accent     = { 7, 8, 9 },
    theme_name = "untouched",
  }
end

local style = sink()
T.eq(themes.apply(style, "fixture-bundled"), true, "apply() returns true for a real theme")
T.eq(style.theme_name, "fixture-bundled", "apply() sets theme_name")
T.neq(style.background, { 1, 2, 3 }, "apply() overwrote background")
T.neq(style.accent, { 7, 8, 9 }, "apply() overwrote accent")

style = sink()
local before_bg, before_accent = style.background, style.accent
T.eq(themes.apply(style, "no-such-theme"), false, "apply() returns false for an unknown theme")
T.eq(style.theme_name, "untouched", "a failed apply leaves theme_name alone")
T.eq(style.background, before_bg, "a failed apply leaves background alone")
T.eq(style.accent, before_accent, "a failed apply leaves accent alone")

-- and the sink is still usable: a failed apply must not leave the style table
-- in a state where the next one cannot work.
T.eq(themes.apply(style, "fixture-bundled"), true, "a valid apply works after a failed one")
T.eq(style.theme_name, "fixture-bundled", "and it takes effect")
