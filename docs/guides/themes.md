# Themes

cdin's visual style is controlled by the `style` table in `data/core/style.lua`.
Everything — background color, text color, font, line height, caret width —
is a field in that table. A theme is just a Lua file that sets some of those
fields.

One theme ships in every build: `default`. It comes from
[cdin-x](https://github.com/m-mdy-m/cdin-x) and is copied into
`build/<platform>-<build>/data/themes/default/theme.lua` at build time. cdin-x
has more; install it and they appear through its theme switcher.

Themes are plain Lua files. No package manager, no registry.

Themes are looked up in three places, in order — user first, then the build's
own bundled set, then any root an extension registered:

```
~/.config/cdin/user/themes/<name>/theme.lua           yours
<site>/X/themes/<name>/theme.lua                      cdin-x's, once installed
build/<platform>-<build>/data/themes/<name>/theme.lua  the mandatory default
```

Because the user directory is searched first, dropping a `dracula/theme.lua`
into `~/.config/cdin/user/themes/` makes `config.theme = "dracula"` work
without touching anything else.

An extension registers its own root with `core.themes.add_root(dir)`, which
also rescans. That matters because the theme list used to be a snapshot taken
at require time: a theme that appeared later was loadable by name but never
listed, and a `config.theme` naming it fell back to the default for the first
frame. The list is now rescanned when a root is added, and `config.theme` is
re-applied at startup once the extensions have registered theirs.

To switch themes, set `config.theme = "mytheme"` in your
`~/.config/cdin/user/init.lua`.

---

## Writing a theme

Create `~/.config/cdin/user/themes/mytheme/theme.lua`:

```lua
-- ~/.config/cdin/user/themes/mytheme/theme.lua
local common = require "core.utils.common"

-- helper that converts a hex string to an RGBA table
local function color(hex)
  return { common.color(hex) }
end

return {
  name            = "mytheme",
  background      = color "#1e1e2e",
  background2     = color "#181825",
  background3     = color "#313244",
  text            = color "#cdd6f4",
  dim             = color "#6c7086",
  caret           = color "#f5c2e7",
  selection       = color "#45475a",
  line_highlight  = color "#1e1e2e",
  line_number     = color "#6c7086",
  line_number2    = color "#cdd6f4",
  accent          = color "#89b4fa",
  scrollbar       = color "#45475a",
  scrollbar_track = color "#181825",
}
```

A theme **returns** a table — it does not mutate `style` directly. Any field
you leave out keeps the default from `data/core/style.lua`. A nested
`syntax = { ... }` table, if present, overrides the syntax colors in the same
way; see the bundled `default/theme.lua` for a complete example.

To use it, set `config.theme = "mytheme"` in your
`~/.config/cdin/user/init.lua`.

---

## Style fields

These are all the fields the editor reads from the `style` table. Setting any
of them overrides the default. You don't have to set all of them — only the
ones you want to change.

### Colors

| Field | What it colors |
|-------|---------------|
| `style.background` | Editor area background |
| `style.background2` | Tree view and panel backgrounds |
| `style.background3` | Highlighted items (autocomplete selection, etc.) |
| `style.text` | Normal editor text |
| `style.dim` | Dimmed text (e.g. inactive items) |
| `style.caret` | The cursor |
| `style.selection` | Selected text background |
| `style.line_highlight` | Background of the line the cursor is on |
| `style.line_number` | Gutter line numbers |
| `style.line_number2` | Gutter line number for the current line |
| `style.accent` | Accent color (active tab indicator, focus rings) |
| `style.scrollbar` | Scrollbar thumb |
| `style.scrollbar_track` | Scrollbar track |
| `style.divider` | Divider lines between panels |
| `style.drag_overlay` | Overlay shown when dragging a split |
| `style.drag_overlay_tab` | Overlay shown when dragging over a tab bar |
| `style.good` | Positive status indicators |
| `style.warn` | Warning indicators |
| `style.error` | Error indicators |
| `style.modified` | Modified file indicator (tabs, status bar) |

Color values are `{ r, g, b }` or `{ r, g, b, a }` tables where each
component is a number from 0 to 255. The `common.color(hex)` helper converts
a hex string for you:

```lua
local r, g, b, a = common.color "#89b4fa"
style.accent = { r, g, b, a }

-- or in one step, using the spread:
style.accent = { common.color "#89b4fa" }
```

### Syntax token colors

Syntax highlighting tokens map to style fields:

| Field | Token type |
|-------|-----------|
| `style.syntax["normal"]` | Plain text |
| `style.syntax["symbol"]` | Identifiers |
| `style.syntax["comment"]` | Comments |
| `style.syntax["keyword"]` | Keywords (`if`, `for`, `return`, …) |
| `style.syntax["keyword2"]` | Secondary keywords (types, builtins) |
| `style.syntax["number"]` | Numeric literals |
| `style.syntax["literal"]` | Other literals (`true`, `false`, `nil`, …) |
| `style.syntax["string"]` | String literals |
| `style.syntax["operator"]` | Operators |
| `style.syntax["function"]` | Function names at call sites |

```lua
style.syntax["keyword"]  = color "#cba6f7"
style.syntax["string"]   = color "#a6e3a1"
style.syntax["comment"]  = color "#585b70"
style.syntax["function"] = color "#89dceb"
```

### Fonts

Fonts are set on the `style.font` and `style.code_font` fields. They take a
`renderer.font` value, loaded with `renderer.font.load`:

```lua
local font_path = EXEFILE .. "/../data/fonts/monospace.ttf"   # the bundled copy
style.code_font = renderer.font.load(font_path, 14 * SCALE)
```

`EXEFILE` is the path to the cdin binary. `SCALE` is the display scale factor
(1.0 on a normal display, 2.0 on HiDPI). Multiply font sizes by `SCALE` so
things look right on both.

The bundled fonts are in `build/<platform>-<build>/data/fonts/`, next to the
binary:

| File | Default use |
|------|------------|
| `font.ttf` | UI text (menus, status bar, tree) and `style.big_font` |
| `monospace.ttf` | Editor (code) text |
| `icons.ttf` | Icons (used internally by the UI) |

To use a system font or your own, provide the full path.

| File | Default use |
|------|------------|
| `font.ttf` | UI text (menus, status bar, tree) and `style.big_font` |
| `monospace.ttf` | Editor (code) text |
| `icons.ttf` | Icons (used internally by the UI) |

To use a system font or your own, provide the full path.

#### Fallback fonts (non-Latin scripts, emoji)

`font.ttf`/`monospace.ttf` are typically Latin-only. stb_truetype (cdin's
rasterizer) can only draw glyphs a font file actually contains and has no
built-in "try another font" behavior, so any codepoint outside a font's
coverage — Arabic/Persian presentation forms, CJK, emoji — renders as a
blank box unless you give the font a fallback chain:

```lua
local arabic = renderer.font.load(EXEFILE .. "/../data/fonts/fallback.ttf", 14 * SCALE)
style.code_font:add_fallback(arabic)
-- keep a reference alongside the primary font — see the note below
style._fallback_fonts = style._fallback_fonts or {}
table.insert(style._fallback_fonts, arabic)
```

`add_fallback` tries the primary font first for each character, then walks
the fallback chain (in the order added) until it finds a font with a real
glyph for that codepoint; if none has one, it draws with the primary font
(typically a `.notdef`/tofu box) rather than nothing. Up to 8 fallbacks per
font.

`style.lua` already does this automatically for `style.font`, `big_font`
and `code_font` if `data/fonts/fallback.ttf` and/or `data/fonts/emoji.ttf`
exist next to the binary
exist — drop suitable files there and no extra config is needed:

- **`fallback.ttf`** — broad-coverage text font, e.g. Noto Sans Arabic or
  Noto Naskh Arabic for Arabic/Persian/Urdu.
- **`emoji.ttf`** — must be an *outline* (vector) font. stb_truetype
  cannot rasterize color bitmap or `COLR`/`CPAL` emoji fonts (Noto Color
  Emoji, Apple Color Emoji, Segoe UI Emoji all fail to load or render
  blank); a monochrome outline emoji font is required. Both files are
  optional — if absent, cdin runs exactly as it does today.

The `style._fallback_fonts` table above is required, not cosmetic: the C
side stores only a raw pointer to each fallback font in the chain. If
nothing on the Lua side keeps the fallback font's userdata reachable,
Lua's garbage collector can free it while it's still wired into the
chain, and the next draw that needs it reads freed memory. Keep a
reference for as long as the primary font (and thus the chain) is alive.

### Metrics

| Field | What it controls |
|-------|-----------------|
| `style.padding` | General padding (used in menus, tabs, etc.) |
| `style.caret_width` | Caret width in pixels |
| `style.tab_width` | Width of the tab indicator in the tab bar |
| `style.scrollbar_size` | Scrollbar width |
| `style.expanded_scrollbar_size` | Scrollbar width when hovered |
| `style.line_height` | Multiplier applied to the font's line height |
| `style.border_radius` | Corner radius for rounded UI elements |

---

## Vim mode colors

The vim plugin adds per-mode color indicators to the status bar. The color of
the `[NORMAL]`, `[INSERT]`, and `[VISUAL]` label is controlled by these fields
on the `style` table:

```lua
style.vim_normal_color  = color "#89b4fa"   -- blue
style.vim_insert_color  = color "#a6e3a1"   -- green
style.vim_visual_color  = color "#f9e2af"   -- yellow
```

Set these in your theme file or in `data/user/init.lua` to match your palette.

---

## Tips

**Override only what you need.** A theme doesn't have to set every field. Load
the default first (by doing nothing) and then override specific colors. This
way your theme automatically inherits any new fields added in future versions.

**Check `data/core/style.lua` for the authoritative list.** The table in that
file is the ground truth. The fields listed here are accurate as of this
writing, but the source file is always up to date.

**Use `core.log` for debugging.** If a color isn't appearing where you expect,
add a `core.log(tostring(style.background))` call temporarily to check what
value is actually set.

**Reload without restarting.** You can reload your user module from the command
palette with `core:reload-module`. This re-runs `data/user/init.lua`, so
color changes take effect immediately — useful when you're iterating on a
theme.