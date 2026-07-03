# Commands and Keybindings

Every action in cdin is a named command. Commands are grouped by namespace
(`doc:`, `root:`, `treeview:` …) and can be run from the command palette
(`Ctrl+Shift+P`), bound to keys with `keymap.add`, or invoked from Lua with
`command.perform("name")`.

Commands are context-sensitive: a `doc:` command only runs when a document
view is active, tree view commands only when the tree has focus, and so on.
When a key is bound to several commands, the first one valid in the current
context runs.

This page lists every command in the current release with its default
binding, if it has one. Unbound commands are still available through the
palette or a custom binding.

For the modal (vim) keys — `hjkl`, `dd`, `:w`, the `m` menu — see
[Vim Keybindings](../guides/vim-keybindings.md). Those are handled by the
vim plugin before the keymap and are not regular commands.

## core

| Command | Binding | Description |
|---|---|---|
| `core:find-command` | `Ctrl+Shift+P` | command palette |
| `core:find-file` | `Ctrl+P` | fuzzy-open a file from the project |
| `core:open-file` | `Ctrl+O` | open a file by path |
| `core:new-doc` | `Ctrl+N` | new untitled document |
| `core:toggle-fullscreen` | `Alt+Return` | toggle fullscreen |
| `core:quit` | — | quit (asks about unsaved files) |
| `core:force-quit` | — | quit without asking |
| `core:open-log` | — | open the log view |
| `core:open-user-module` | — | open `data/user/init.lua` |
| `core:open-project-module` | — | open/create `.lite_project.lua` |
| `core:reload-module` | — | reload a Lua module at runtime |

## doc — editing

| Command | Binding | Description |
|---|---|---|
| `doc:save` | `Ctrl+S` | save |
| `doc:save-as` | `Ctrl+Shift+S` | save under a new name |
| `doc:rename` | — | rename the file on disk |
| `doc:undo` | `Ctrl+Z` | undo |
| `doc:redo` | `Ctrl+Y` | redo |
| `doc:cut` | `Ctrl+X` | cut |
| `doc:copy` | `Ctrl+C` | copy |
| `doc:paste` | `Ctrl+V` | paste |
| `doc:newline` | `Return` | insert newline (with auto-indent) |
| `doc:newline-below` | `Ctrl+Return` | open a line below |
| `doc:newline-above` | `Ctrl+Shift+Return` | open a line above |
| `doc:backspace` | `Backspace` | delete backwards |
| `doc:delete` | `Delete` | delete forwards |
| `doc:delete-to-previous-word-start` | `Ctrl+Backspace` | delete the previous word |
| `doc:delete-to-next-word-end` | `Ctrl+Delete` | delete the next word |
| `doc:delete-lines` | `Ctrl+Shift+K` | delete the current line(s) |
| `doc:duplicate-lines` | `Ctrl+Shift+D` | duplicate the current line(s) |
| `doc:move-lines-up` | `Ctrl+Up` | move line(s) up |
| `doc:move-lines-down` | `Ctrl+Down` | move line(s) down |
| `doc:join-lines` | `Ctrl+J` | join selected lines |
| `doc:indent` | `Tab` | indent selection |
| `doc:unindent` | `Shift+Tab` | unindent selection |
| `doc:toggle-line-comments` | `Ctrl+/` | comment / uncomment |
| `doc:upper-case` | — | selection to upper case |
| `doc:lower-case` | — | selection to lower case |
| `doc:toggle-line-ending` | — | switch between LF and CRLF |
| `doc:go-to-line` | `Ctrl+G` | jump to a line |

## doc — selection

| Command | Binding | Description |
|---|---|---|
| `doc:select-all` | `Ctrl+A` | select everything |
| `doc:select-none` | `Escape` | clear the selection |
| `doc:select-word` | `Ctrl+D` | select the word under the caret |
| `doc:select-lines` | `Ctrl+L` | expand the selection to whole lines |

## doc — movement

Every movement command has a matching `select-to-` variant bound to the same
key plus `Shift`.

| Command | Binding |
|---|---|
| `doc:move-to-previous-char` / `next-char` | `Left` / `Right` |
| `doc:move-to-previous-line` / `next-line` | `Up` / `Down` |
| `doc:move-to-previous-word-start` | `Ctrl+Left` |
| `doc:move-to-next-word-end` | `Ctrl+Right` |
| `doc:move-to-previous-block-start` | `Ctrl+[` |
| `doc:move-to-next-block-end` | `Ctrl+]` |
| `doc:move-to-start-of-line` / `end-of-line` | `Home` / `End` |
| `doc:move-to-start-of-doc` / `end-of-doc` | `Ctrl+Home` / `Ctrl+End` |
| `doc:move-to-previous-page` / `next-page` | `PageUp` / `PageDown` |

## find-replace

| Command | Binding | Description |
|---|---|---|
| `find-replace:find` | `Ctrl+F` | incremental find in the current file |
| `find-replace:repeat-find` | `F3` / `F4` | next match |
| `find-replace:previous-find` | `Shift+F3` | previous match |
| `find-replace:select-next` | `Ctrl+D` | add the next occurrence to the selection |
| `find-replace:replace` | `Ctrl+R` | find and replace (plain text) |
| `find-replace:find-pattern` | — | find with a Lua pattern |
| `find-replace:replace-pattern` | — | replace with a Lua pattern |
| `find-replace:replace-symbol` | — | replace a whole symbol |

## project-search

Results open in a results view; inside it `Up`/`Down` move and `Return`
jumps to the match.

| Command | Binding | Description |
|---|---|---|
| `project-search:find` | `Ctrl+Shift+F` | search all project files (plain text) |
| `project-search:find-pattern` | — | search with a Lua pattern |
| `project-search:fuzzy-find` | — | fuzzy search across the project |
| `project-search:refresh` | `F5` | rerun the search |
| `project-search:select-previous` / `select-next` | `Up` / `Down` | move through results |
| `project-search:open-selected` | `Return` | open the selected result |

## root — splits and tabs

| Command | Binding | Description |
|---|---|---|
| `root:close` | `Ctrl+W` | close the current tab |
| `root:switch-to-next-tab` | `Ctrl+Tab` | next tab |
| `root:switch-to-previous-tab` | `Ctrl+Shift+Tab` | previous tab |
| `root:move-tab-left` / `right` | `Ctrl+PageUp` / `Ctrl+PageDown` | reorder tabs |
| `root:switch-to-tab-1` … `tab-9` | `Alt+1` … `Alt+9` | jump to a tab |
| `root:split-left` / `right` / `up` / `down` | `Alt+Shift+J/L/I/K` | split the view |
| `root:switch-to-left` / `right` / `up` / `down` | `Alt+J/L/I/K` | move focus between splits |
| `root:grow` / `root:shrink` | — | resize the current split |

## treeview

| Command | Binding | Description |
|---|---|---|
| `treeview:toggle` | `Ctrl+\` / `F2` | show / hide the tree |
| `treeview:focus` | `Ctrl+Shift+E` / `F3` | focus the tree |
| `treeview:focus-and-refresh` | — | focus and rescan |
| `treeview:refresh` | — | rescan the project |
| `treeview:toggle-hidden` | `Ctrl+Shift+H`* | show / hide dotfiles |
| `treeview:new-file` | `Ctrl+Shift+N` | create a file |
| `treeview:new-directory` | `Ctrl+Shift+Alt+N` | create a directory |

\* bound in the default `data/user/init.lua`, not in core.

When the tree has focus: `Up`/`Down` move the cursor, `Return` opens,
`Left` collapses (or goes to the parent), `Right` expands (or goes to the
first child), `Ctrl+R` renames, `Delete` deletes,
`Ctrl+Shift+R` refreshes.

## autocomplete

The completion popup appears while typing (symbols from open documents,
minimum 3 characters).

| Command | Binding | Description |
|---|---|---|
| `autocomplete:complete` | `Tab` | accept the suggestion |
| `autocomplete:next` / `previous` | `Down` / `Up` | move through suggestions |
| `autocomplete:cancel` | `Escape` | dismiss the popup |

## command — the command view prompt

Active while a prompt is open: `Tab` completes (`command:complete`),
`Return` submits (`command:submit`), `Escape` cancels (`command:escape`),
`Up`/`Down` move through suggestions (`command:select-previous` /
`command:select-next`).

## trim-whitespace

| Command | Binding | Description |
|---|---|---|
| `trim-whitespace:trim-trailing-whitespace` | — | strip trailing whitespace |

The plugin also trims automatically on every save.

## vim-fmenu and vim-shell

The actions behind the `m` menu and the `:` shell integration are plain
commands too, so they can be bound directly:

`vim-fmenu:open`, `vim-fmenu:new-file`, `vim-fmenu:new-dir`,
`vim-fmenu:rename`, `vim-fmenu:copy`, `vim-fmenu:move`, `vim-fmenu:delete`,
`vim-fmenu:refresh`, `vim-fmenu:pwd`, `vim-fmenu:cd-up`,
`vim-fmenu:git-status`, `vim-fmenu:git-log`, `vim-fmenu:git-add-all`,
`vim-fmenu:git-diff`

`vim-shell:run-custom`, `vim-shell:git-status`, `vim-shell:git-log`,
`vim-shell:git-diff`, `vim-shell:make`, `vim-shell:make-test`

`vim-fmenu:open` is bound to `m` in normal mode. The shell commands run the
named command and open its output in a scratch buffer.
