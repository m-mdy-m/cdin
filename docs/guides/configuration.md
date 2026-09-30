# Configuration

cdin is configured through your personal config file:
`~/.config/cdin/user/init.lua`. It loads last, after the core and
all extensions, so anything you set there overrides the defaults.

To open it from inside the editor, run `core:open-user-module` from the
command palette (`Ctrl+Shift+P`).

---

## Config values

All options live in the `config` table:

```lua
local config = require "core.config"

config.indent_size = 4
config.tab_type = "hard"
```

### Extensions

| Option | Default | Description |
|--------|---------|-------------|
| `config.plugins` | `nil` | Which **site** plugins load. `nil` = all, `false` = none, a table = a whitelist. Does not affect the mandatory bundled set. |
| `config.site_dirname` | `"site"` | The name of the installed-extensions directory, under `<data_home>/cdin/`. |
| `config.site_dir` | (unset) | A full path, which overrides `site_dirname` entirely. |
| `config.site_path()` | — | Resolves the site directory. Call this; do not read a path out of the table. |

#### The site directory

Where cdin-x is installed, and where the loader looks for site plugins:
`$XDG_DATA_HOME`/`cdin/<name>` or `~/.local/share/cdin/<name>` on Linux and
macOS; on Windows `%LOCALAPPDATA%`, then `%APPDATA%`, then
`%USERPROFILE%\AppData\Local`, each plus `\cdin\<name>`.

**`config.site_dirname` is the one knob.** Change it and everything follows —
the loader, the theme registry, and cdin-x, which reads this table rather than
computing a path of its own:

```lua
-- ~/.config/cdin/user/init.lua
config.site_dirname = "extensions"     -- ~/.local/share/cdin/extensions
```

It is resolved lazily by `config.site_path()` rather than once at load,
precisely so that this works: your `init.lua` runs *after* `core.config` has
been required, so a value computed at load would already be fixed before you
had a chance to change it.

"site" is the word vim and neovim use for exactly this directory (`:h
site-dir`) — third-party content, as opposed to the editor's own. If you have
no vim background, `extensions` is the more obvious choice and it costs
nothing to switch.

For a location outside the data home entirely, set the full path instead:

```lua
config.site_dir = "/opt/whatever/cdin-extensions"
```

#### What loads

```lua
-- Load nothing from the site. The bundled set — vim, the default theme,
-- the fonts — is part of the build and is unaffected.
config.plugins = false
```

```lua
-- Load only these two from the site.
config.plugins = { "palette", "finder" }
```

`--no-plugins` is the command-line spelling of `config.plugins = false`. It
does **not** disable the bundled set: `--no-plugins` cannot turn vim off in an
editor that has no other modal editing.

The user `init.lua` runs **before** extensions load, so a key binding set here
is one a plugin has to override, not the other way round. `require`-ing an
extension's module works (the site roots are already on `package.path`), but
its `init()` side effects are not there yet.

### Editor

| Option | Default | Description |
|--------|---------|-------------|
| `config.indent_size` | `2` | Spaces per indent level |
| `config.tab_type` | `"soft"` | `"soft"` (spaces) or `"hard"` (tabs) |
| `config.line_limit` | `80` | Column where the line guide is drawn |
| `config.highlight_current_line` | `true` | Highlight the line the cursor is on |
| `config.line_height` | `1.2` | Line height multiplier |
| `config.max_undos` | `10000` | Maximum undo steps stored |
| `config.undo_merge_timeout` | `0.3` | Consecutive edits within this many seconds are merged into one step |
| `config.symbol_pattern` | `"[%a_][%w_]*"` | Lua pattern defining what counts as a "word" |
| `config.non_word_chars` | (punctuation) | Characters that word motions stop at |

### Vim mode

| Option | Default | Description |
|--------|---------|-------------|
| `config.vim_mode_enabled` | `true` | Enable or disable modal editing |
| `config.scrolloff` | `5` | Lines of context kept above/below the cursor while scrolling |
| `config.line_number_relative` | `false` | Show line numbers relative to the cursor |

### Files

| Option | Default | Description |
|--------|---------|-------------|
| `config.file_size_limit` | `10` | Maximum file size in MB the editor will open |
| `config.ignore_files` | `"^%."` | Lua pattern for files to hide from the project scanner |

### Rendering

| Option | Default | Description |
|--------|---------|-------------|
| `config.fps` | `60` | Target frame rate |
| `config.mouse_wheel_scroll` | `54 * SCALE` | Pixels scrolled per mouse wheel tick |

### Project scanner

| Option | Default | Description |
|--------|---------|-------------|
| `config.project_scan_rate` | `10` | How often (in seconds) the background thread rescans project files |

### Logs

| Option | Default | Description |
|--------|---------|-------------|
| `config.max_log_items` | `80` | Maximum entries kept in the log view |
| `config.message_timeout` | `3` | Seconds a status bar message stays visible |

### Tree view

| Option | Default | Description |
|--------|---------|-------------|
| `config.treeview_size` | `200 * SCALE` | Width of the tree panel in pixels |
| `config.show_hidden_files` | `true` | Show dot files in the tree |
| `config.treeview_git_enabled` | `true` | Show git status markers (A/M/D/?) |
| `config.treeview_git_update_rate` | `2` | Seconds between git status polls |

### Autocomplete

| Option | Default | Description |
|--------|---------|-------------|
| `config.autocomplete_max_suggestions` | `6` | Maximum suggestions shown |

### Session

| Option | Default | Description |
|--------|---------|-------------|
| `config.session_restore` | `false` | Reopen the last session on startup |
| `config.session_save_on_quit` | `true` | Save the session automatically on quit |
| `config.session_max_recent` | `10` | Number of recent files/dirs to remember |

---

## Keybindings

Add or override keybindings with `keymap.add`:

```lua
local keymap = require "core.input.keymap"

keymap.add {
  ["ctrl+escape"] = "core:quit",
  ["ctrl+h"]      = "find-replace:replace",
}
```

To override an existing binding, pass `true` as the second argument:

```lua
keymap.add({ ["ctrl+s"] = "doc:save-as" }, true)
```

Modifier names are lowercase and separated by `+`. A stroke can map to a
single command or a list — cdin tries each in order and stops at the first
one that does anything:

```lua
keymap.add {
  ["escape"] = { "command:escape", "doc:select-none" },
}
```

A full list of commands and their default bindings is in the
[Command Reference](commands.md).

---

## Themes

Three themes are available. Load one in `data/user/init.lua`:

```lua
-- warm dark theme
require "user.colors.fall"

-- light theme
require "user.colors.summer"

-- default (near-black, purple accent) — no require needed
```

To write your own theme, create a Lua file in `data/user/colors/` and set
fields on the `style` table:

```lua
local style  = require "core.style"
local common = require "core.utils.common"

style.background = { common.color "#1e1e2e" }
style.text       = { common.color "#cdd6f4" }
style.caret      = { common.color "#f5c2e7" }
style.accent     = { common.color "#89b4fa" }
-- ... and so on
```

See `data/core/style.lua` for the full list of style fields and their
defaults.

---

## Project-local config

Drop a `.lite_project.lua` file in the root of any project directory and
cdin loads it automatically when you open that directory. Use it for
per-project overrides:

```lua
-- .lite_project.lua
local config = require "core.config"
config.indent_size = 4
config.tab_type = "hard"
```

It's a plain Lua script with the same context as `user/init.lua`. To create
or open it from the editor, run `core:open-project-module` from the command
palette.

---

## Example user config

```lua
local config = require "core.config"
local keymap = require "core.input.keymap"

-- indentation
config.indent_size = 4
config.tab_type = "soft"

-- vim
config.scrolloff = 8
config.line_number_relative = true

-- session
config.session_restore = true

-- theme
require "user.colors.fall"

-- extra keybindings
keymap.add {
  ["ctrl+escape"] = "core:quit",
  ["ctrl+h"]      = "find-replace:replace",
}
```