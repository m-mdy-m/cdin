# Themes

A theme is one Lua file returning a table of colours. There is no theme format,
no inheritance, no theme engine, and no theme manager in this repository.

```
<root>/<name>/theme.lua
```

That layout is the whole contract, and it is the layout cdin's registry reads
unmodified — which is why a directory can be handed to
`require("core.themes").add_root()` as-is.

**One theme ships in every build: `default`.** It comes from
[cdin-x](https://github.com/m-mdy-m/cdin-x) and is copied into
`build/<platform>-<build>/data/themes/default/theme.lua` at build time. A build
has to be able to start, and it has to have something to start with, so exactly
one theme is mandatory. cdin-x ships ten; install it and the rest appear in its
theme switcher.

## The fastest way

Point the registry at a directory. No build, no manifest, no install:

```lua
-- ~/.config/cdin/user/init.lua
require("core.themes").add_root(os.getenv("HOME") .. "/my-themes")
```

Each subdirectory holding a `theme.lua` becomes a theme. This is the right way
to try one out and the right way to keep your own, since a directory you own can
be version-controlled and symlinked independently of the editor.

Or, with no code at all, put it in your own themes directory — the first place
the registry looks:

```
~/.config/cdin/user/themes/my-theme/theme.lua
```

## Where themes are found

In order, and the first hit wins:

1. `config.user_dir/themes` — yours
2. `EXEDIR/data/themes` — the bundled one
3. every root added with `require("core.themes").add_root()` — extensions, in the
   order they were added

**So you can override a bundled theme by name.** Drop a `default/` directory in
your own themes root and the bundled `default` stops being what loads. That is
the intended way to tweak the default theme rather than forking it.

`add_root` is called by cdin-x's entry plugin to register the extension catalog's
themes — before anything else, because `config.theme` is applied at
`style.lua` load time, long before any plugin runs. If a root appears *after*
load time the list is rescanned, so a plugin that installs its themes during its
own `init()` can still have them listed and selectable; and if the theme named by
your session file only resolves once plugins have registered their roots, the
runtime retries unconditionally after loading them. (Nothing watches the theme
files — there is no key that turns a watcher on.)

## Every key

A theme sets **some** of these. Any key it omits keeps the value it already had,
so a six-colour theme works, and that is deliberate: a theme should be able to be
a *variation*, not a complete specification. An error would make the six-colour
theme impossible.

Colours are hex strings. **The one exception is `search_highlight`, which is
`{ r, g, b, a }`** — four numbers, not a hex string, because it has to be
composited over whatever is behind it, and a hex string with an alpha channel
would be a second colour format for one key. A table is passed through
untouched, so that is the only way to express one.

### Surfaces and text

| key | what it colours | fallback |
| --- | --- | --- |
| `background` | the editor's own backdrop | `#050507` |
| `background2` | the one behind it — tab bar, status bar | `#0b0b10` |
| `background3` | one step further forward — menus, the popup | `#15151c` |
| `text` | ordinary text | `#d8d8df` |
| `caret` | the cursor | `#ffffff` |
| `accent` | the one saturated colour in the scheme, used sparingly | `#a89bd8` |
| `dim` | secondary text — hints, inactive entries | `#707080` |
| `divider` | the lines between things | `#252530` |
| `selection` | the selected region | `#252536` |
| `search_highlight` | `{ r, g, b, a }` — matches | `{ 255, 210, 80, 90 }` |

### Gutter and scrollbars

| key | what it colours | fallback |
| --- | --- | --- |
| `line_number` | the gutter | `#555565` |
| `line_number2` | the current line's number | `#a89bd8` |
| `line_highlight` | the current line's background | `#111119` |
| `scrollbar` | the scrollbar thumb, at rest | `#090910` |
| `scrollbar2` | the scrollbar thumb, hovered or dragged | `#55556a` |

`line_number` and `line_number2` are two colours rather than one bolded number
because the current line has to be findable at a glance in a hundred-line file,
and that is easier with a different hue than with a different weight.

### Title bar

| key | what it colours | fallback |
| --- | --- | --- |
| `titlebar_text` | the title, unfocused | `#9a9aaa` |
| `titlebar_text_focus` | …focused | `#eeeeff` |
| `titlebar_button_hover` | a button under the mouse | `#303040` |
| `titlebar_close_hover` | the close button, hovered | `#e06060` |

### Git

| key | what it colours | fallback |
| --- | --- | --- |
| `git_modified` | tracked, with changes | `#d0ad55` |
| `git_added` | staged | `#65b875` |
| `git_deleted` | deleted | `#d06060` |
| `git_conflict` | in conflict | `#e07050` |
| `git_untracked` | untracked | `#888899` |
| `git_renamed` | renamed | `#9b8de0` |

**These six live in the runtime, not in a plugin.** They are a shared vocabulary
rather than one extension's colours: every bundled theme defines all six, and
several independent places read them with an `or` fallback — the status bar's
branch display in core, and cdin-x's treeview badges. They are kept here as the
neutral pre-theme value rather than picking one consumer to own them.

With no git extension loaded nothing reads them, and you can leave them out.

### Vim mode

`vim_pill_fg`, `vim_normal_bg`, `vim_insert_bg`, `vim_visual_bg`,
`vim_replace_bg`, `vim_command_bg`.

**The runtime has no fallbacks for these, and that is the interesting part.**
They are cdin-x's vocabulary: the mode pill and the command line are drawn by
vim mode, which is a bundled extension, not by core. A theme that omits them
works fine until vim mode is loaded, at which point those reads are `nil` and the
renderer falls back to **opaque white** — a white pill, not a missing one.

Every bundled theme in cdin-x defines all six, so this only bites a hand-written
theme. If you write one by hand and the mode pill is white, this is why. The fix
is to define them, or to give them a default from an extension with
`style.set_fallback(key, hex)` before vim mode reads them.

The six `git_*` keys are the opposite case: they **do** have core fallbacks,
because they are a shared vocabulary that several independent places read.

**The pill has to be legible at a glance.** That is the one job it has, and a
scheme can be beautiful and still leave normal and visual mode indistinguishable.
That is the part of a theme people get wrong.

### Syntax

The tokens the highlighter emits. A syntax *definition* decides which type a span
gets; these decide what colour that type is. That split is the whole contract
between a language definition and a colour scheme.

| key | what it colours | fallback |
| --- | --- | --- |
| `normal` | the base for anything not otherwise classified | `#d8d8df` |
| `symbol` | identifiers | `#c4c4d0` |
| `comment` | comments | `#686878` |
| `keyword` | the language's own reserved words | `#9b8cff` |
| `keyword2` | a second class of them — types, builtins, second-level keywords | `#7f75c8` |
| `number` | numeric literals | `#e0a060` |
| `literal` | `true`, `false`, `nil` — values rather than words | `#aaaac0` |
| `string` | strings | `#86c986` |
| `operator` | operators | `#ccccd8` |
| `function` | function names | `#75b9ed` |

A `type` a definition emits that has no key here is **not** guaranteed to fall back
to `normal`. One of the three draw paths in `docview.lua` does
(`style.syntax[type] or style.syntax["normal"]`); the other two pass
`style.syntax[t.type]` straight to the renderer, which turns a missing colour into
opaque white. So a typo in a syntax definition can render as ordinary text, as
white, or as a partly-coloured line depending on which span it lands in.

Define every `type` your definitions emit. The full vocabulary the shipped
definitions use is `string`, `comment`, `comment2`, `number`, `operator`,
`function`, `symbol`, `keyword`, `keyword2`, `literal`, `normal`, and `special`
— and the last two have no key here either.

`keyword` and `keyword2` are two classes on purpose. A language with one big
reserved-word list renders as a wall of identical colour; splitting it lets `self`
and `true` stand out from `if` and `end` without a theme having to know any
particular language.

### Not colours

These are numbers, set before the theme loads, and a theme **can** override them
because the applier copies every key that is not `name` or `syntax`:

| key | what it is |
| --- | --- |
| `padding` | `{ x, y }` in pixels — `14, 7`, scaled |
| `divider_size` | 1 |
| `scrollbar_size` | 4 |
| `caret_width` | 2 |
| `tab_width` | 170 |
| `titlebar_height` | 34 |
| `titlebar_button_width` | 46 |

There is no `caret_block_alpha` key. One existed with a default of `0.55` and a
documented failure mode — at `1` the selection under a block cursor became
invisible — but **there is no block cursor in this editor**, so nothing read it and
it has been removed. A theme that still sets it lands an unused number on `style`.

## A worked example

Start from a theme you already like. This copies `default`, darkens it, and
warms the accent — about eight lines of difference:

```lua
local base = dofile(os.getenv("HOME") .. "/my-themes/default/theme.lua")

local M = {}
for k, v in pairs(base) do
  if type(v) == "table" then
    M[k] = {}
    for k2, v2 in pairs(v) do M[k][k2] = v2 end
  else
    M[k] = v
  end
end

M.name            = "default-warm"
M.background      = "#0a0908"
M.background2     = "#131110"
M.accent          = "#d08770"
M.syntax.keyword  = "#c4a882"
M.syntax.comment  = "#6b6055"

return M
```

Two things about that shape.

**Copying is a deep copy.** `M = base` and then changing one colour would change
the original — and the original is on disk and shared, so the change is not
reverted when you close the editor. Walking the nested `syntax` table by hand is
the price of not doing that. `search_highlight` is a table too, so it needs the
same treatment; getting it wrong is how a copied theme ends up with a shared
highlight table that one edit mutates for everybody.

**The directory name is the theme's identity.** `require("core.themes").names()`
returns directory names, and that is what a switcher has to list and what
`config.theme` has to be set to. The file's own `name` field only becomes
`style.theme_name` — a label for the status of the current theme, not a lookup
key. The two are not required to agree, and a mismatch is confusing rather than
fatal: the theme still loads, and `theme_name` simply says something else.

## How it works

**A theme is a table, and the runtime does the rest.** The registry reads the
table, keeps every key it did not supply, and hands the result to the `style`
table everything draws with. `style.theme_name` records which one it was.

**`themes.apply(style, name)` copies every key except `name` and `syntax`.** The
nested `syntax` table is merged key by key rather than replaced, which is what
lets a theme set one syntax colour and inherit the other nine.

**Strings are parsed to colours; tables are passed through.** That is the entire
mechanism behind the `search_highlight` exception — a table is not a colour
string, so it is used as-is, and RGBA is already the internal representation.

**Selection order is user, then bundled, then extension roots in the order added.**
`add_root` ignores a path that is not a directory rather than registering it, so
a caller cannot poison the search order with something that will never resolve.
Adding the same root twice is a no-op.

**The runtime never installs a theme picker.** Setting `config.theme` and
restarting works; changing it at runtime is one call:

```lua
require("core.style").set_theme("nord")
```

cdin-x's theme switcher is that call plus a list, and `session-theme-switcher` is
what remembers the choice across restarts. Two plugins, because "change it now"
and "remember that I did" are separate questions and some people want the first
without the second.

## Files

| file | holds |
| --- | --- |
| [`data/core/themes.lua`](../../data/core/themes.lua) | the registry: roots, discovery, apply |
| [`data/core/style.lua`](../../data/core/style.lua) | every fallback, and the metrics a theme can override |
| `X/themes/<name>/theme.lua` | the ten themes, in cdin-x |
