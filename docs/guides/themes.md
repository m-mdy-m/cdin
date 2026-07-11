# Themes

cdin's visual style is controlled by the `style` table in `data/core/style.lua`.
Everything — background color, text color, font, line height, caret width —
is a field in that table. A theme is just a Lua file that sets some of those
fields.

Themes live in `data/user/colors/`. Three are bundled:

| Require | Description |
|---------|-------------|
| (none) | Default: near-black background, muted grays, single purple accent |
| `require "user.colors.fall"` | Warm dark theme — browns and ambers |
| `require "user.colors.summer"` | Light theme — off-white background |

To switch, add one line to `data/user/init.lua`:

```lua
require "user.colors.fall"
```

---

## Writing a theme

Create a file in `data/user/colors/`. The name is yours; the `require` path
will match it.

```lua
-- data/user/colors/mytheme.lua
local style  = require "core.style"
local common = require "core.utils.common"

-- helper that converts a hex string to an RGBA table
local function color(hex)
  return { common.color(hex) }
end

style.background        = color "#1e1e2e"
style.background2       = color "#181825"
style.background3       = color "#313244"
style.text              = color "#cdd6f4"
style.dim               = color "#6c7086"
style.caret             = color "#f5c2e7"
style.selection         = color "#45475a"
style.line_highlight    = color "#1e1e2e"
style.line_number       = color "#6c7086"
style.line_number2      = color "#cdd6f4"
style.accent            = color "#89b4fa"
style.scrollbar         = color "#45475a"
style.scrollbar_track   = color "#181825"
```

Then load it in `data/user/init.lua`:

```lua
require "user.colors.mytheme"
```

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
local font_path = EXEFILE .. "/../data/fonts/JetBrainsMono-Regular.ttf"
style.code_font = renderer.font.load(font_path, 14 * SCALE)
```

`EXEFILE` is the path to the cdin binary. `SCALE` is the display scale factor
(1.0 on a normal display, 2.0 on HiDPI). Multiply font sizes by `SCALE` so
things look right on both.

The bundled fonts are in `data/fonts/`:

| File | Default use |
|------|------------|
| `FiraSans-Regular.ttf` | UI text (menus, status bar, tree) |
| `JetBrainsMono-Regular.ttf` | Editor (monospace) text |
| `icomoon.ttf` | Icons (used internally by the UI) |

To use a system font or your own, provide the full path.

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