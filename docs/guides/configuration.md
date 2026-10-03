# Configuration

Everything is configured in one file:

```
~/.config/cdin/user/init.lua
```

It is plain Lua. **`core` and `config` are not globals** — the editor raises on
any undeclared global, so `require` what you need:

```lua
local core    = require "core"
local config  = require "core.config"
local keymap  = require "core.input.keymap"
local command = require "core.input.command"
local themes  = require "core.themes"

config.indent_size = 4
keymap.add { ["ctrl+g"] = "doc:go-to-line" }
command.add(nil, { ["my:hello"] = function() core.log("hi") end })
```

Writing bare `config.indent_size = 4` or `core.log(...)` in this file raises
`cannot get undefined variable`. That is not pedantry — it is what makes a typo
in a plugin's global a loud failure instead of a silent one.

The cdin-x `modules` plugin adds a `core:open-user-module` command that opens
this file from inside the editor. The runtime does not: opening a file is a
workflow, and workflows live in plugins.

## When it runs, and why that matters

The order is fixed, and two details in it are load-bearing:

```
1. config defaults          data/core/config.lua
2. command.add_defaults()   every runtime command and binding
3. your init.lua            ← you are here
4. config.plugins = false   if --no-plugins was passed
5. bundled plugins          unconditional: vim and the manager, always
6. site plugins             whatever your config.plugins selected
7. .lite_project.lua        the project module, if there is one
```

**Your file runs before the plugins.** Two consequences, one of which people rely
on without noticing and one of which bites them:

- A key you set is one a plugin **can** override. Because `keymap.add` prepends,
  a plugin loading after you *will* come first — so to beat a plugin you need
  `keymap.add(map, true)`, not a second `keymap.add`.
- You **cannot** `require` a site plugin's module from here. The loader extends
  `package.path` as the first statement of step 6, and you are at step 3. Setting
  configuration and binding keys is what your file is for; anything that needs a
  site plugin's code has to happen in that plugin.

The alternative — running your config last — would make cdin-x's palette
impossible to rebind, because nothing could come after it. That is the whole
reason for this order.

**`--no-plugins` is applied after your file, not before.** So
`config.plugins = { "vim" }` and `cdin --no-plugins` together give you the
bundled set and nothing else; the flag wins. It also means you cannot use your
config to defend against the flag, which is intended — it is a debugging tool,
not a policy.

**`.lite_project.lua` runs last, after plugins.** Project-local configuration
therefore *can* override a plugin's choices, which is the opposite of what your
`init.lua` can do. That asymmetry is deliberate: a project's settings should
win over your personal ones, and a plugin is a third thing again.

## Where things live

```lua
-- Windows
--   user_dir   %APPDATA%\cdin\user                     (~/.config/cdin/user elsewhere)
--   data_home  %LOCALAPPDATA%\cdin
-- POSIX
--   user_dir   ${XDG_CONFIG_HOME:-~/.config}/cdin/user
--   data_home  ${XDG_DATA_HOME:-~/.local/share}/cdin
```

| key | default | what it does |
| --- | --- | --- |
| `config.user_dir` | `<config_home>/cdin/user` | where `init.lua` and your own themes are looked up |
| `config.user_root` | `<config_home>/cdin` | the parent of the above |
| `config.data_home` | `<data_home>/cdin` | the base every other path hangs off |
| `config.site_dirname` | `"site"` | the site directory's **name**, under `data_home` |
| `config.site_dir` | unset | a full path, which overrides `site_dirname` entirely |
| `config.fonts_dir` | `EXEDIR/data/fonts` | bundled with the binary; do not repoint it |
| `config.data_dir` | `EXEDIR/data` | where a build's bundled set lives. Read by extensions; do not repoint it |

**One directory is not under `data_home`, and it is worth knowing which.**
`session.lua` — the last directory and the persisted theme, read before anything
else loads — is at `${XDG_DATA_HOME:-~/.local/share}/cdin/session.lua` on POSIX
but at `%APPDATA%\cdin\session.lua` on Windows, where `data_home` is
`%LOCALAPPDATA%`. Nothing in the runtime writes that file: cdin only reads it,
and cdin-x's session plugin is what puts it there.

**One knob, and every consumer follows it.** `config.site_dirname` decides where
installed extensions live, and the plugin loader, the theme registry and cdin-x
all read the resolved path rather than computing one of their own. Rename it and
everything follows together; set `site_dir` and the name stops mattering.

`site` is the word vim and neovim use for exactly this directory
(`:h site-dir`) — third-party content, as opposed to the editor's own. It is the
editor's name to choose, and cdin-x is told rather than assumed: the installer
mirrors whatever it is set to.

`config.site_path()` resolves it. **Call it; do not read a path out of the
table.** It is resolved at the point of use rather than cached into a field at
load time, because this very file runs after `core.config` was required — a
value computed then would be fixed before you had a chance to change it, and the
one knob would silently do nothing.

## Plugins

```lua
config.plugins = nil          -- every site plugin   (default)
config.plugins = false        -- no site plugins
config.plugins = { "vim-tab", "search" }   -- only these
```

Anything other than `nil`, `false` or a list of names is treated as `nil`.

**This selects the *site* set only, and it has no effect on the bundled set.**
The bundled set is the mandatory one a build copies in — vim mode, the extension
manager, the default theme, the fonts — and it loads whatever this says, including `false`. That is
why `--no-plugins` cannot turn vim off: a cdin without vim is not an editor, and
a debugging flag is not a policy.

So `config.plugins = false` means *"the bare editor"*, not *"the editor with
nothing"*. The bundled set still loads, and the editor still starts, renders,
edits and answers <kbd>Ctrl</kbd>+<kbd>N</kbd>.

Note the corollary, and it is the one that surprises people: **a cdin-x checkout
installed into the site directory is a site plugin**, so `config.plugins = false`
and `--no-plugins` both switch off the palette, the finders, the tree, tabs,
search and git. If you are wondering why an extension you installed from the
panel vanished, this is *not* the answer — the manager keeps those in a store of
its own and never reads `config.plugins`. Disable it in the panel instead; that
choice persists.

There is a whitelist form for when you want most of it but not all of it. Names
are the directory names under `plugins/`, not manifest names, and the whitelist
applies to the site directory alone.

## Themes

| key | default | what it does |
| --- | --- | --- |
| `config.theme` | `"default"` | the theme applied at load time |

`config.theme` is applied at `style.lua` load time, which is **before any plugin
runs**. A theme that only exists in a root an extension registers later can
therefore fall back silently at startup — so after plugins load, the runtime
retries: if `config.theme` differs from what actually applied and now resolves to
a real file, it is applied again. That retry is unconditional.

There is no `config.theme_auto_reload` key. It existed once with the default
`true` and was read nowhere — there is no file watcher — so it has been removed
rather than left as a knob that does nothing.

Prefer changing themes at runtime — cdin-x's theme switcher does this, and it
writes `config.theme` — over editing `config.theme` and restarting.

Themes are cdin-x's: the format and the full colour list are in
[adding a theme](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-theme.md). The runtime's half — the roots a theme
is looked up in, and `themes.apply` — is in
[the extension contract](../architecture/extension-contract.md#themes).

## Text

| key | default | what it does |
| --- | --- | --- |
| `config.indent_size` | `2` | spaces per indent level, and the width of one unindent step |
| `config.tab_type` | `"soft"` | `"hard"` inserts a literal tab; anything else inserts spaces |
| `config.line_height` | `1.2` | line height as a multiple of the font size |
| `config.highlight_current_line` | `true` | draw the current line's background |
| `config.line_number_relative` | `false` | show line numbers relative to the cursor |
| `config.scrolloff` | `5` | lines of context kept when scrolling past the ends |
| `config.non_word_chars` | see file | the word boundaries movement uses |

`config.indent_size` is used for *backspace as well as indent*: at the start of
a run of spaces it deletes a whole step rather than one space. That is why
<kbd>Backspace</kbd> over a four-space indent removes four columns with
`indent_size = 4` and one with `indent_size = 1`.

`config.non_word_chars` is the one to change if a movement key does the wrong
thing in a language with unusual identifiers. It is not validated against
anything — a pattern that does not compile is a pattern that matches nothing,
silently.

### One key core does not read

| key | default | status |
| --- | --- | --- |
| `config.symbol_pattern` | `"[%a_][%w_]*"` | not read by core — movement uses `non_word_chars` alone. cdin-x's search and autocomplete plugins **do** read it (`X/core/search/buffer.lua`, `X/core/autocomplete/source.lua`), so it is not dead, just not a core guarantee. |

If you are chasing a movement bug, `non_word_chars` is the key that matters.

## Direction and shaping

| key | default | what it does |
| --- | --- | --- |
| `config.direction` | `"auto"` | `"auto"` per-line base direction, `"ltr"` left-to-right, `"rtl"` right-to-left |
| `config.shaping_enabled` | `true` | join Arabic and Indic letterforms into their shaped forms |

These are runtime keys, not plugin keys, because the shaper and the bidi
resolver are in the text pipeline. cdin-x's `rtl_toggle` plugin cycles
`config.direction` and flips `config.shaping_enabled` for you; it is two
commands over keys that already exist here.

Turn shaping off if you are editing text in an Arabic script and want the
isolated forms — it is a real difference when reading letter by letter, and the
default is on because the shaped forms are what a reader expects.

## Behaviour

| key | default | what it does |
| --- | --- | --- |
| `config.fps` | `60` | frame rate cap |
| `config.project_scan_rate` | `10` | seconds between project file rescans |
| `config.max_log_items` | `80` | entries kept in the log view |
| `config.message_timeout` | `3` | seconds a transient message stays up |
| `config.undo_merge_timeout` | `0.3` | seconds within which consecutive edits merge into one undo step |
| `config.max_undos` | `10000` | undo stack depth |
| `config.file_size_limit` | `10` | megabytes; larger files are not indexed by the project scan |
| `config.ignore_files` | `"^%."` | a Lua pattern; matching entries are skipped by the scan |
| `config.mouse_wheel_scroll` | `54 * SCALE` | pixels per wheel notch |

**`config.undo_merge_timeout` is the one people want to change and do not know
exists.** Typing is merged into a single undo step while the gaps between
keystrokes are under the timeout, so <kbd>Ctrl</kbd>+<kbd>Z</kbd> takes back a
word rather than a character. Raising it makes undo coarser; setting it to `0`
makes every edit its own step.

`config.ignore_files` is a pattern, not a glob, and it applies to the **project
scan** — the file list the tree and the finders read. It does not stop you
opening a dotfile by name. cdin-x's git plugin layers its own ignore rules on
top of this, and is the better place to change them.

## Owned by plugins, not here

These are deliberately **absent** from `data/core/config.lua`. Each is defined by
the plugin that uses it, with its own default, so the key does not outlive the
plugin and cannot drift from it:

| key | owner |
| --- | --- |
| `config.vim_mode_enabled` | cdin-x's `vim` plugin, which also binds <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>V</kbd> to it |
| `config.session_restore` | cdin-x's `session` plugin |
| `config.session_restore_dir`, `config.session_restore_theme` | owned by cdin-x's `session`, but the **runtime defaults both to `true`** at boot (`data/core/init.lua:6-7`) and reads the persisted theme before anything else loads |
| `config.site_dir` set by cdin-x | cdin-x's manager, to the same value you set |
| `config.extension_dir` | the manager: where extensions installed from the panel are copied. Default `<data_home>/cdin/extensions/X` |
| `config.registry_dir` | the manager: where the catalog index is kept. Default `<data_home>/cdin/registry/cdin-x`; the `CDIN_X_REGISTRY` environment variable overrides it |
| `config.registry_url`, `config.registry_raw_url` | the manager: where the catalog is downloaded from. The raw URL is derived from the first; `CDIN_X_BRANCH` picks the branch |
| `config.state_file` | the manager: which extensions you disabled. Default `<data_home>/cdin/extensions.lua` |
| `config.pluginmanager_size`, `config.pluginmanager_min` | the manager's panel: its width, `460 * SCALE`, and its narrowest, `300 * SCALE` |
| `config.bundle_dir` | the manager: defaults to `config.data_dir`, and is `nil` for an extension set that is not sitting beside a build |

Every one of those is written onto the same `config` table you `require`, so
`config.foo` in your own file reads them — but only **after** the manager has
loaded, which is step 5 of the order above, after your file has already run. Set
one and the manager's `or` default leaves your value alone; read one and you are
reading whatever was there when you ran.

**A key a plugin declares in its manifest is a declaration, not an application.**
Nothing copies it onto `config` for you. If a plugin documents a default, set it
yourself:

```lua
config.vim_mode_enabled = true   -- the documented default, stated explicitly
```

A copy of a plugin's default in `data/core/config.lua` would be a key that
outlives the plugin: meaningless once it is disabled, and one more place for the
two to disagree.

## Setting a default

Use a `nil` guard rather than an assignment, so your file and a plugin can both
express a default without the last one loaded winning:

```lua
if config.indent_size == nil then config.indent_size = 4 end
```

You will rarely need this — the point is that it is *possible*. A plain
assignment is a decision, and a decision made in your config is exactly what
should beat a plugin.

## Files

| file | holds |
| --- | --- |
| [`data/core/config.lua`](../../data/core/config.lua) | every default, and the path resolution |
| [`data/core/preboot.lua`](../../data/core/preboot.lua) | the session state read before anything else loads |
