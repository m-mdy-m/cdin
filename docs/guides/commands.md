# Command Reference

This is a list of all built-in commands and their default keybindings.

Commands can be run directly from the command palette (`Ctrl+Shift+P`). You can also bind any command to a key in your user config:

```lua
keymap.add {
  ["ctrl+shift+f"] = "project-search:find",
}
```

---

## Core commands

| Command | Default binding | Description |
|---------|----------------|-------------|
| `core:find-command` | `Ctrl+Shift+P` | Open the command palette |
| `core:find-file` | `Ctrl+P` | Fuzzy-open a file from the project |
| `core:open-file` | `Ctrl+O` | Open a file by path |
| `core:new-doc` | `Ctrl+N` | Open a new empty document |
| `core:toggle-fullscreen` | `Alt+Return` | Toggle fullscreen mode |
| `core:open-log` | — | Open the editor log view |
| `core:open-user-module` | — | Open `data/user/init.lua` |
| `core:open-project-module` | — | Open or create `.lite_project.lua` |
| `core:reload-module` | — | Reload a Lua module by name |
| `core:quit` | — | Quit (with unsaved-changes dialog) |
| `core:force-quit` | — | Quit immediately without saving |

---

## Document commands

| Command | Default binding | Description |
|---------|----------------|-------------|
| `doc:save` | `Ctrl+S` | Save current document |
| `doc:save-as` | `Ctrl+Shift+S` | Save current document to a new path |
| `doc:undo` | `Ctrl+Z` | Undo |
| `doc:redo` | `Ctrl+Y` | Redo |
| `doc:cut` | `Ctrl+X` | Cut selection |
| `doc:copy` | `Ctrl+C` | Copy selection |
| `doc:paste` | `Ctrl+V` | Paste |
| `doc:select-all` | `Ctrl+A` | Select all |
| `doc:select-none` | `Escape` | Clear selection |
| `doc:select-lines` | `Ctrl+L` | Select current line(s) |
| `doc:select-word` | `Ctrl+D` | Select word under cursor |
| `doc:indent` | `Tab` | Indent selection |
| `doc:unindent` | `Shift+Tab` | Unindent selection |
| `doc:newline` | `Return` | Insert newline |
| `doc:newline-below` | `Ctrl+Return` | Insert newline below without splitting the current line |
| `doc:newline-above` | `Ctrl+Shift+Return` | Insert newline above |
| `doc:go-to-line` | `Ctrl+G` | Go to line number |
| `doc:toggle-line-comments` | `Ctrl+/` | Toggle line comments |
| `doc:join-lines` | `Ctrl+J` | Join next line to current |
| `doc:delete` | `Delete` | Delete character after cursor |
| `doc:backspace` | `Backspace` | Delete character before cursor |
| `doc:delete-to-previous-word-start` | `Ctrl+Backspace` | Delete to start of previous word |
| `doc:delete-to-next-word-end` | `Ctrl+Delete` | Delete to end of next word |
| `doc:delete-lines` | `Ctrl+Shift+K` | Delete current line(s) |
| `doc:duplicate-lines` | `Ctrl+Shift+D` | Duplicate current line(s) |
| `doc:move-lines-up` | `Ctrl+Up` | Move selected lines up |
| `doc:move-lines-down` | `Ctrl+Down` | Move selected lines down |

---

## Navigation commands

| Command | Default binding | Description |
|---------|----------------|-------------|
| `doc:move-to-previous-char` | `Left` | Move left |
| `doc:move-to-next-char` | `Right` | Move right |
| `doc:move-to-previous-line` | `Up` | Move up |
| `doc:move-to-next-line` | `Down` | Move down |
| `doc:move-to-previous-word-start` | `Ctrl+Left` | Move to previous word start |
| `doc:move-to-next-word-end` | `Ctrl+Right` | Move to next word end |
| `doc:move-to-previous-block-start` | `Ctrl+[` | Move to previous block start |
| `doc:move-to-next-block-end` | `Ctrl+]` | Move to next block end |
| `doc:move-to-start-of-line` | `Home` | Move to line start |
| `doc:move-to-end-of-line` | `End` | Move to line end |
| `doc:move-to-start-of-doc` | `Ctrl+Home` | Move to document start |
| `doc:move-to-end-of-doc` | `Ctrl+End` | Move to document end |
| `doc:move-to-previous-page` | `PageUp` | Scroll up one page |
| `doc:move-to-next-page` | `PageDown` | Scroll down one page |

Each of these has a `select-to-*` variant (e.g. `doc:select-to-previous-char`) triggered by holding `Shift`. For example, `Shift+Right` maps to `doc:select-to-next-char`.

---

## Find and replace

| Command | Default binding | Description |
|---------|----------------|-------------|
| `find-replace:find` | `Ctrl+F` | Open find bar |
| `find-replace:replace` | `Ctrl+R` | Open replace bar |
| `find-replace:repeat-find` | `F3` | Jump to next match |
| `find-replace:previous-find` | `Shift+F3` | Jump to previous match |
| `find-replace:select-next` | `Ctrl+D` | Add next occurrence to selection |

---

## Split panes

| Command | Default binding | Description |
|---------|----------------|-------------|
| `root:split-left` | `Alt+Shift+J` | Split pane to the left |
| `root:split-right` | `Alt+Shift+L` | Split pane to the right |
| `root:split-up` | `Alt+Shift+I` | Split pane upward |
| `root:split-down` | `Alt+Shift+K` | Split pane downward |
| `root:switch-to-left` | `Alt+J` | Move focus to left pane |
| `root:switch-to-right` | `Alt+L` | Move focus to right pane |
| `root:switch-to-up` | `Alt+I` | Move focus to pane above |
| `root:switch-to-down` | `Alt+K` | Move focus to pane below |
| `root:close` | — | Close active view |

---

## Tabs

| Command | Default binding | Description |
|---------|----------------|-------------|
| `root:switch-to-tab-1` | `Alt+1` | Switch to tab 1 |
| `root:switch-to-tab-2` | `Alt+2` | Switch to tab 2 |
| `root:switch-to-tab-3` | `Alt+3` | Switch to tab 3 |
| `root:switch-to-tab-4` | `Alt+4` | Switch to tab 4 |
| `root:switch-to-tab-5` | `Alt+5` | Switch to tab 5 |
| `root:switch-to-tab-6` | `Alt+6` | Switch to tab 6 |
| `root:switch-to-tab-7` | `Alt+7` | Switch to tab 7 |
| `root:switch-to-tab-8` | `Alt+8` | Switch to tab 8 |
| `root:switch-to-tab-9` | `Alt+9` | Switch to tab 9 |
| `root:switch-to-next-tab` | — | Switch to next tab (used by vim `Tab` in Normal mode) |

---

## Tree view

| Command | Default binding | Description |
|---------|----------------|-------------|
| `treeview:toggle-hidden` | `Ctrl+Shift+H` | Toggle hidden file visibility |
| `treeview:focus-and-refresh` | — | Focus the tree and rescan |
| `treeview:refresh` | — | Rescan project files |

---

## Vim-specific commands

These are used internally by the vim mode plugin:

| Command | Description |
|---------|-------------|
| `vim-fmenu:open` | Open the file manager menu |

---

## Whitespace

| Command | Description |
|---------|-------------|
| `trim-whitespace:trim-trailing-whitespace` | Strip trailing whitespace from the current document |

This runs automatically on every save. You can also bind it to a key if you want to run it manually without saving.

---

## Command palette

`Ctrl+Shift+P` opens the command palette. It shows all commands that are currently valid (based on what view is focused). Type to filter by name. Command names are shown in a readable form (e.g. `Doc: Save`). The right side shows the current keybinding if one exists.

---

## Key stroke format

Key strokes in the keymap use this format:

- Modifier names: `ctrl`, `shift`, `alt`, `altgr`
- Modifiers are separated by `+`
- Key names are lowercase: `a`, `b`, `return`, `escape`, `tab`, `backspace`, `delete`, `home`, `end`, `pageup`, `pagedown`, `up`, `down`, `left`, `right`, `f1`–`f12`
- Special: `keypad enter`, `left ctrl`, `right ctrl` (for modifier disambiguation)

Examples: `"ctrl+s"`, `"ctrl+shift+p"`, `"alt+return"`, `"shift+f3"`, `"f3"`.