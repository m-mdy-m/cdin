# Vim Keybindings

cdin's modal editing is implemented by the `plugins/vim` plugin family:
`vimode.lua` (modes and normal-mode keys), `ex.lua` (the `:` command line),
`fmenu.lua` (the `m` action menu) and `shell.lua` (shell commands in
buffers). It is a deliberate subset of vim — the everyday keys, not an
emulation layer. Counts, registers, marks and text objects are not
implemented yet.

Vim mode is on by default. To turn it off, set
`config.vim_mode_enabled = false` in `data/user/init.lua`. All the regular
`Ctrl`-based bindings keep working either way, since keys with `ctrl`/`alt`
modifiers are passed straight through to the normal keymap.

## Modes

Every buffer starts in NORMAL mode. The status bar (bottom left) shows the
current mode: `[NORMAL]`, `[INSERT]` or `[VISUAL]`.

- `i` — insert at the caret
- `a` — insert after the caret
- `A` — insert at end of line
- `I` — insert at start of line
- `o` — open a line below and insert
- `O` — open a line above and insert
- `v` — visual mode (extends the selection with motions)
- `Esc` — back to NORMAL mode; in NORMAL mode it clears the selection

## Motions (NORMAL and VISUAL)

| Key | Motion |
|---|---|
| `h` `j` `k` `l` | left, down, up, right |
| `w` / `e` | next word end |
| `b` | previous word start |
| `0` | start of line |
| `$` (`shift+4`) | end of line |
| `^` (`shift+6`) | start of line |
| `gg` | start of file |
| `G` | end of file |

In VISUAL mode the same keys extend the selection instead of moving the
caret.

## Operators and editing

| Key | Action |
|---|---|
| `x` | delete the character under the caret |
| `dd` | delete the current line |
| `yy` | yank (copy) the current line |
| `cc` | change the current line (delete it and enter INSERT) |
| `D` | delete to end of line |
| `J` | join the next line onto this one |
| `p` | paste |
| `u` | undo |
| `r` | redo (note: this is redo, not vim's replace-char) |

Double-key sequences (`gg`, `dd`, `yy`, `cc`) have a 0.6 second timeout
between the two presses.

In VISUAL mode:

| Key | Action |
|---|---|
| `d` / `x` | delete the selection |
| `y` | yank the selection |
| `>` / `<` | indent / unindent |

## Search

| Key | Action |
|---|---|
| `/` | open find |
| `n` / `N` | next / previous match |
| `*` | search for the word under the caret |

## Other normal-mode keys

| Key | Action |
|---|---|
| `:` | open the ex command line |
| `m` | open the action menu (see below) |
| `Tab` | switch to the next tab |

## Ex commands

Press `:` to open the command line. `Up`/`Down` browse the command history
(the last 100 commands). Tab-completion suggests command names and, for
file commands, paths. `:help` opens this reference in a buffer.

File commands:

```
:w              save current file
:w!             force-save (same as :w in cdin)
:wa             save all open files
:q              close current view (fails if unsaved)
:q!             force-close without saving
:qa  :qall      quit (fails if there are unsaved files)
:qa! :qall!     force quit
:wq  :x         save then close
:wqa :xa        save all then quit
```

Open and create:

```
:e <path>       open a file (error if it doesn't exist)
:edit <path>    alias for :e
:new <path>     create a file and open it
```

Filesystem:

```
:mkdir <path>          create a directory (with parents)
:rm <path>             remove a file or directory tree
:delete <path>         alias for :rm
:rename <old> <new>    rename (open buffers follow the rename)
:copy <src> <dst>      copy a file or directory
:move <src> <dst>      move (open buffers follow the move)
```

Navigation:

```
:ls [path]      list a directory in a scratch buffer
:pwd            print the working directory
:cd <path>      change the working directory
:tree           focus and refresh the project tree
:<number>       jump to a line, e.g. :42
```

Shell:

```
:!<cmd>         run a shell command; output opens in a scratch buffer
                examples:  :!ls -la    :!git status    :!npm test
```

Shell output buffers are ordinary documents — you can search them, copy from
them, and close them with `:q`.

## The action menu (`m`)

Press `m` to open a single-key action menu. It is context-aware: when the
tree view has a selected item the actions apply to it, otherwise to the file
in the active view. Sections and keys:

**Files** — `n` new file, `N` new directory, `o` open file, `r` rename,
`y` copy, `v` move, `x` delete (with a y/n confirmation).

**Navigate** — `f` change directory, `u` up one level, `.` reveal in tree,
`R` refresh tree, `/` project search.

**Git** — `s` status, `l` log (last 20, oneline), `d` diff, `a` add all,
`c` commit (prompts for a message), `P` push, `p` pull, `b` branches.
Output opens in a scratch buffer.

**Build** — `m` runs `make`, `t` runs `make test`.

**Shell** — `!` run a custom command, `w` pwd, `e` env, `i` network info.

The same actions are available as named commands (`vim-fmenu:*`,
`vim-shell:*`) in the command palette, so you can bind them to keys directly.

## Known limitations in this beta

- No counts (`5j`), registers, marks, macros or text objects.
- `r` is redo, not replace-char.
- `d`/`y`/`c` only work as line operations (`dd`, `yy`, `cc`) or on a visual
  selection — `dw`, `ciw` and similar operator+motion combinations are not
  implemented.
- Yank/paste use the system clipboard; there are no separate registers.