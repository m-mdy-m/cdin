# Command Reference

Every user-visible action in cdin is a named command. You can run any of them
from the command palette (`Ctrl+Shift+P`), which shows all commands that are
currently valid and their keybindings. You can also bind any command to a key
in your user config:

```lua
local keymap = require "core.input.keymap"
keymap.add {
  ["ctrl+shift+f"] = "project-search:find",
}
```

To override an existing binding, pass `true` as the second argument:

```lua
keymap.add({ ["ctrl+s"] = "doc:save-as" }, true)
```

---

## Core

| Command | Binding | Description |
|---------|---------|-------------|
| `core:find-command` | `Ctrl+Shift+P` | Command palette |
| `core:find-file` | `Ctrl+P` | Fuzzy-open a file from the project |
| `core:open-file` | `Ctrl+O` | Open a file by path |
| `core:new-doc` | `Ctrl+N` | New empty document |
| `core:toggle-fullscreen` | `Alt+Return` | Toggle fullscreen |
| `core:open-log` | — | Open the editor log view |
| `core:open-user-module` | — | Open `data/user/init.lua` |
| `core:open-project-module` | — | Open or create `.lite_project.lua` |
| `core:reload-module` | — | Reload a Lua module by name |
| `core:quit` | — | Quit (prompts if there are unsaved changes) |
| `core:force-quit` | — | Quit immediately without saving |

---

## Document editing

| Command | Binding | Description |
|---------|---------|-------------|
| `doc:save` | `Ctrl+S` | Save |
| `doc:save-as` | `Ctrl+Shift+S` | Save to a new path |
| `doc:undo` | `Ctrl+Z` | Undo |
| `doc:redo` | `Ctrl+Y` | Redo |
| `doc:cut` | `Ctrl+X` | Cut selection |
| `doc:copy` | `Ctrl+C` | Copy selection |
| `doc:paste` | `Ctrl+V` | Paste |
| `doc:select-all` | `Ctrl+A` | Select all |
| `doc:select-none` | `Escape` | Clear selection |
| `doc:select-lines` | `Ctrl+L` | Select current line(s) |
| `doc:select-word` | `Ctrl+D` | Select word under cursor (or add next occurrence) |
| `doc:indent` | `Tab` | Indent selection |
| `doc:unindent` | `Shift+Tab` | Unindent selection |
| `doc:newline` | `Return` | Insert newline |
| `doc:newline-below` | `Ctrl+Return` | Insert newline below without splitting the current line |
| `doc:newline-above` | `Ctrl+Shift+Return` | Insert newline above |
| `doc:go-to-line` | `Ctrl+G` | Jump to line number |
| `doc:toggle-line-comments` | `Ctrl+/` | Toggle line comments |
| `doc:join-lines` | `Ctrl+J` | Join the next line onto this one |
| `doc:delete` | `Delete` | Delete character forward |
| `doc:backspace` | `Backspace` | Delete character backward |
| `doc:delete-to-previous-word-start` | `Ctrl+Backspace` | Delete to start of previous word |
| `doc:delete-to-next-word-end` | `Ctrl+Delete` | Delete to end of next word |
| `doc:delete-lines` | `Ctrl+Shift+K` | Delete current line(s) |
| `doc:duplicate-lines` | `Ctrl+Shift+D` | Duplicate current line(s) |
| `doc:move-lines-up` | `Ctrl+Up` | Move selected lines up |
| `doc:move-lines-down` | `Ctrl+Down` | Move selected lines down |

---

## Navigation

| Command | Binding | Description |
|---------|---------|-------------|
| `doc:move-to-previous-char` | `Left` | Move left |
| `doc:move-to-next-char` | `Right` | Move right |
| `doc:move-to-previous-line` | `Up` | Move up |
| `doc:move-to-next-line` | `Down` | Move down |
| `doc:move-to-previous-word-start` | `Ctrl+Left` | Previous word start |
| `doc:move-to-next-word-end` | `Ctrl+Right` | Next word end |
| `doc:move-to-previous-block-start` | `Ctrl+[` | Previous block start |
| `doc:move-to-next-block-end` | `Ctrl+]` | Next block end |
| `doc:move-to-start-of-line` | `Home` | Line start |
| `doc:move-to-end-of-line` | `End` | Line end |
| `doc:move-to-start-of-doc` | `Ctrl+Home` | Document start |
| `doc:move-to-end-of-doc` | `Ctrl+End` | Document end |
| `doc:move-to-previous-page` | `PageUp` | Page up |
| `doc:move-to-next-page` | `PageDown` | Page down |

Every movement has a `select-to-*` variant triggered by holding `Shift`
(e.g. `Shift+Right` selects to the next character, `Ctrl+Shift+End`
selects to the end of the document).

---

## Find and replace

| Command | Binding | Description |
|---------|---------|-------------|
| `find-replace:find` | `Ctrl+F` | Open find bar |
| `find-replace:repeat-find` | `F4` | Jump to next match |
| `find-replace:previous-find` | `Shift+R` | Jump to previous match |
| `find-replace:select-next` | `Ctrl+D` | Add next occurrence to selection |
| `find-replace:clear-highlight` | `Ctrl+Shift+H` | Clear search highlight |
| `find-replace:replace` | — | Open replace bar (no default binding) |
| `find-replace:replace-pattern` | — | Replace with Lua pattern (no default binding) |
| `find-replace:replace-symbol` | — | Replace whole-word symbol (no default binding) |

The replace commands are available from the command palette or you can bind them:

```lua
keymap.add { ["ctrl+h"] = "find-replace:replace" }
```

---

## Tabs

The tab plugin adds proper multi-tab management on top of the core view system.

| Command | Binding | Description |
|---------|---------|-------------|
| `tab:new` | `Ctrl+T` | Open a new tab |
| `tab:close` | `Ctrl+Shift+W` | Close the current tab |
| `tab:next` | `Ctrl+Tab` | Switch to the next tab |
| `tab:prev` | `Ctrl+Shift+Tab` | Switch to the previous tab |
| `tab:go-1` … `tab:go-9` | `Ctrl+1` … `Ctrl+9` | Jump to tab by number |
| `tab:move-left` | `Ctrl+Shift+PageUp` | Move current tab left |
| `tab:move-right` | `Ctrl+Shift+PageDown` | Move current tab right |

The status bar shows `[N/total]` when more than one tab is open.

---

## Window splits

The window plugin handles split panes, focus movement, and resizing.

| Command | Binding | Description |
|---------|---------|-------------|
| `window:vsplit` | `Ctrl+\` | Split vertically (side by side) |
| `window:split` | `Ctrl+Shift+\` | Split horizontally (stacked) |
| `window:close` | `Alt+C` | Close the focused pane |
| `window:only` | `Alt+O` | Close all other panes |
| `window:focus-left` | `Alt+H` | Focus the pane to the left |
| `window:focus-down` | `Alt+J` | Focus the pane below |
| `window:focus-up` | `Alt+K` | Focus the pane above |
| `window:focus-right` | `Alt+L` | Focus the pane to the right |
| `window:focus-next` | `Alt+W` | Cycle focus forward |
| `window:focus-prev-window` | `Alt+P` | Cycle focus backward |
| `window:increase-width` | `Alt+Right` | Widen the focused pane |
| `window:decrease-width` | `Alt+Left` | Narrow the focused pane |
| `window:increase-height` | `Alt+Up` | Tall the focused pane |
| `window:decrease-height` | `Alt+Down` | Shorten the focused pane |
| `window:equalize` | `Alt+=` | Equalize all pane sizes |

There are also `window:split-open` and `window:vsplit-open` which split and
immediately open a file picker — useful to bind if you open files in splits
often.

---

## Tree view

| Command | Binding | Description |
|---------|---------|-------------|
| `treeview:toggle` | `Ctrl+\` / `F2` | Show or hide the tree panel |
| `treeview:focus` | `Ctrl+Shift+E` / `F3` | Move keyboard focus to the tree |
| `treeview:new-file` | `Ctrl+Shift+N` | Create a new file in the project |
| `treeview:new-directory` | `Ctrl+Shift+Alt+N` | Create a new directory |
| `treeview:toggle-hidden` | `Ctrl+Shift+H` | Toggle hidden file visibility |
| `treeview:refresh` | — | Rescan without changing focus |
| `treeview:focus-and-refresh` | — | Focus the tree and rescan |

When the tree is focused, the arrow keys navigate the list, `Return` opens
the selected item, `Delete` deletes it, and `Ctrl+R` renames it.

---

## Project search

| Command | Binding | Description |
|---------|---------|-------------|
| `project-search:find` | `Ctrl+Shift+F` | Search across all project files |
| `project-search:refresh` | `F5` | Re-run the last search |

Results open in a dedicated view. `Up`/`Down` navigate results, `Return`
opens the selected file at the matching line.

---

## Session

| Command | Binding | Description |
|---------|---------|-------------|
| `session:open-recent` | `Ctrl+Shift+R` | Open a recently used file |
| `session:open-recent-dirs` | `Ctrl+Shift+D` | Open a recently used directory |
| `session:save` | `Ctrl+Alt+S` | Save the current session manually |

The session is saved automatically on quit (`config.session_save_on_quit` is
`true` by default). If `config.session_restore` is `true`, the last session
is restored on next launch.

---

## Whitespace

| Command | Description |
|---------|-------------|
| `trim-whitespace:trim-trailing-whitespace` | Strip trailing whitespace from the current document |

This runs automatically on every save. You can also call it manually from
the command palette.

---

## Vim-specific

These are used by the vim mode plugin internally. You can also bind them directly.

| Command | Description |
|---------|-------------|
| `vim-fmenu:open` | Open the `m` action menu |

See [Vim Keybindings](vim-keybindings.md) for the full vim command reference.

---

## Keystroke format

Modifier names: `ctrl`, `shift`, `alt`, `altgr`. Modifiers are separated by
`+`. Key names are lowercase: `a`, `return`, `escape`, `tab`, `backspace`,
`delete`, `home`, `end`, `pageup`, `pagedown`, `up`, `down`, `left`,
`right`, `f1`–`f12`, and so on.

Special: `keypad enter`, `left ctrl`, `right ctrl` (for disambiguation).

Examples: `"ctrl+s"`, `"ctrl+shift+p"`, `"alt+return"`, `"f4"`.

A binding can map to a single command or a list. When it's a list, cdin
tries each command in order and stops at the first one that does anything:

```lua
keymap.add {
  ["escape"] = { "command:escape", "doc:select-none" },
}
```