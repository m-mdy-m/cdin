# Command reference

Every command the runtime registers, and every key it binds. Both are tables you
can copy from: a keystroke here is the string you would put in `keymap.add`, and
a command name is the string you would put in `command.perform`.

**What is not in here is as important as what is.** The command palette, find
file, open file and open folder are *not* runtime commands. They are plugins, in
[cdin-x](https://github.com/m-mdy-m/cdin-x), and they own their own keystrokes.
That is why <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> and
<kbd>Ctrl</kbd>+<kbd>P</kbd> are unbound here: an editor with no extensions
should have no dead keys, and an editor with them should get those keys from the
plugin that actually implements them. A full list of what cdin-x adds is in its
[plugin index](https://github.com/m-mdy-m/cdin-x/blob/main/docs/plugins/README.md).

## The model

A command is a name, a predicate, and a function.

```lua
command.add(predicate, map, overwrite)
command.remove(names)          -- a name, or a list of names
```

`predicate` decides whether the command is *available right now*, which is
different from whether it is registered. It has three legal forms:

| form | available when |
| --- | --- |
| `nil` | always |
| a **string** — a module path | that module's returned function says so; `"core.views.docview"` means *while a document view is active* |
| a **class table** | `core.active_view` is an instance of it |

`overwrite` permits re-registering a name that already exists. Without it,
`command.add` asserts — which is deliberate: two plugins claiming one name is a
bug, and the alternative is a binding that silently runs the wrong thing.

**Availability, not registration, is what a keystroke sees.** `command.perform`
returns `false` when the predicate fails and does nothing. That is why the
runtime can route <kbd>Enter</kbd> to `command:submit` and have it fall through
to `doc:newline` when no prompt is open, instead of erroring.

## Keystrokes

Keys are written the way the editor spells them: lowercase, modifiers in
`ctrl+alt+shift` order joined by `+`, arrows as `left`/`right`/`up`/`down`, and
`keypad enter` distinct from `return`.

A value may be a **list**, which is a fallback chain: the commands are tried in
order and the first whose predicate holds runs. That is how <kbd>Ctrl</kbd>+<kbd>D</kbd>
can belong to find-and-replace while a match is selected and to the document
otherwise, without either knowing the other exists.

## Document

Available while a document view is active. The keys below are the default ones;
several of these are also how vim mode reaches them, which is the point — the
motions are ordinary commands, so a keymap or a vim integration is all it takes
to re-bind them.

### Saving and files

| key | command | does |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>S</kbd> | `doc:save` | save; prompts for a path on an unnamed document |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> | `doc:save-as` | save under a name you type |
| | `doc:rename` | save under a new name and delete the old file |
| | `doc:toggle-line-ending` | flip this document between LF and CRLF |

`doc:save` delegates to `doc:save-as` when there is no filename yet, so the
"you have to name it first" path is the same prompt either way.

`doc:rename` writes the new file, then removes the old one. It repoints any
document already open on the old path. There is no copy-then-delete command in
the runtime — copy and move are filesystem workflows, and the ones in cdin-x
reach for the shell.

### Editing

| key | command | does |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>Z</kbd> | `doc:undo` | |
| <kbd>Ctrl</kbd>+<kbd>Y</kbd> | `doc:redo` | |
| <kbd>Ctrl</kbd>+<kbd>X</kbd> | `doc:cut` | copies the selection to the clipboard, then deletes it |
| <kbd>Ctrl</kbd>+<kbd>C</kbd> | `doc:copy` | no-op with no selection |
| <kbd>Ctrl</kbd>+<kbd>V</kbd> | `doc:paste` | |
| <kbd>Backspace</kbd>, <kbd>Shift</kbd>+<kbd>Backspace</kbd> | `doc:backspace` | deletes a whole indent step at a time in leading whitespace |
| <kbd>Delete</kbd>, <kbd>Shift</kbd>+<kbd>Delete</kbd> | `doc:delete` | at end of line, joins the next one first |
| <kbd>Return</kbd> | `doc:newline` | keeps the current line's indentation |
| <kbd>Ctrl</kbd>+<kbd>Return</kbd> | `doc:newline-below` | |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Return</kbd> | `doc:newline-above` | |
| <kbd>Ctrl</kbd>+<kbd>J</kbd> | `doc:join-lines` | |
| <kbd>Tab</kbd> | `doc:indent` | indents the selection, or inserts one step |
| <kbd>Shift</kbd>+<kbd>Tab</kbd> | `doc:unindent` | |
| <kbd>Ctrl</kbd>+<kbd>/</kbd> | `doc:toggle-line-comments` | |
| <kbd>Ctrl</kbd>+<kbd>Up</kbd> / <kbd>Ctrl</kbd>+<kbd>Down</kbd> | `doc:move-lines-up` / `doc:move-lines-down` | |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>D</kbd> | `doc:duplicate-lines` | |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>K</kbd> | `doc:delete-lines` | |
| | `doc:upper-case` / `doc:lower-case` | operate on the selection |

Vim mode binds bare <kbd>z</kbd> and <kbd>y</kbd> to the same two commands. Those
are **not** runtime bindings and do not appear in the table above — see
[vim mode](vim-keybindings.md).

**`doc:delete` is not a generated command.** It combines two behaviours — clearing
a run of whitespace at the end of a line, then deleting forward one character — so
it is written by hand rather than coming from the translation table. `Delete` is
bound to it, *not* to a `doc:delete-to-next-char` (which does not exist).

**`doc:toggle-line-comments` needs a syntax definition.** It reads
`doc.syntax.comment` and returns without doing anything if there is none — so on
a file with no matching definition the key is silently inert rather than an
error. That is the same "no definition means plain text, and nothing warns you"
rule as everywhere else in the highlighter.

**Word deletion** is a generated command with a different translation, which is
why the binding list looks repetitive:

| key | command |
| --- | --- |
| <kbd>Ctrl</kbd>+<kbd>Backspace</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Backspace</kbd> | `doc:delete-to-previous-word-start` |
| <kbd>Ctrl</kbd>+<kbd>Delete</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Delete</kbd> | `doc:delete-to-next-word-end` |

### Movement

The movement set is generated from a table of sixteen translations
(`data/core/commands/doc.lua`), which is what produces three commands per
translation. `move-to` collapses a selection first; `select-to` extends it;
`delete-to` removes up to it.

| translation | `doc:move-to-…` | `doc:select-to-…` | `doc:delete-to-…` |
| --- | --- | --- | --- |
| `previous-char` | <kbd>←</kbd> | <kbd>Shift</kbd>+<kbd>←</kbd> | |
| `next-char` | <kbd>→</kbd> | <kbd>Shift</kbd>+<kbd>→</kbd> | |
| `previous-word-start` | <kbd>Ctrl</kbd>+<kbd>←</kbd> | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>←</kbd> | <kbd>Ctrl</kbd>+<kbd>Backspace</kbd> |
| `next-word-end` | <kbd>Ctrl</kbd>+<kbd>→</kbd> | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>→</kbd> | <kbd>Ctrl</kbd>+<kbd>Delete</kbd> |
| `previous-block-start` | <kbd>Ctrl</kbd>+<kbd>[</kbd> | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>[</kbd> | |
| `next-block-end` | <kbd>Ctrl</kbd>+<kbd>]</kbd> | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>]</kbd> | |
| `previous-line` | <kbd>↑</kbd> | <kbd>Shift</kbd>+<kbd>↑</kbd> | |
| `next-line` | <kbd>↓</kbd> | <kbd>Shift</kbd>+<kbd>↓</kbd> | |
| `start-of-line` | <kbd>Home</kbd> | <kbd>Shift</kbd>+<kbd>Home</kbd> | |
| `end-of-line` | <kbd>End</kbd> | <kbd>Shift</kbd>+<kbd>End</kbd> | |
| `start-of-doc` | <kbd>Ctrl</kbd>+<kbd>Home</kbd> | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Home</kbd> | |
| `end-of-doc` | <kbd>Ctrl</kbd>+<kbd>End</kbd> | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>End</kbd> | |
| `previous-page` | <kbd>PageUp</kbd> | <kbd>Shift</kbd>+<kbd>PageUp</kbd> | |
| `next-page` | <kbd>PageDown</kbd> | <kbd>Shift</kbd>+<kbd>PageDown</kbd> | |
| `start-of-word` | | | |
| `end-of-word` | | | |

The `delete-to` column is mostly empty because only the two word translations have
a default binding. All sixteen `doc:delete-to-…` commands exist and are available
to a keymap; the ones with no key were simply never given one.

`start-of-word` and `end-of-word` have no binding in any column. They are there
because the table they come from is shared with the word-selection logic, and a
plugin that wants "select to the start of the word under the cursor" should not
have to reimplement the translation.

**Two of the `move-to` commands are not the generated ones.**
`doc:move-to-previous-char` and `doc:move-to-next-char` are overwritten with
versions that collapse an existing selection to its edge first, so
<kbd>←</kbd> shrinks a selection and then starts moving. That is why the arrows
behave the way they do, and it is a deliberate override rather than a special
case in the table.

`start-of-word` and `end-of-word` do not appear in the movement table above
because there is no default binding for them — see the paragraph above.

### Selection

| key | command | does |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>A</kbd> | `doc:select-all` | |
| <kbd>Ctrl</kbd>+<kbd>D</kbd> | `doc:select-word` | the word under the cursor |
| <kbd>Ctrl</kbd>+<kbd>L</kbd> | `doc:select-lines` | whole lines, trailing newline included |
| <kbd>Esc</kbd> | `doc:select-none` | the second half of the <kbd>Esc</kbd> chain |

`<kbd>Esc</kbd>` is bound to `{ "command:escape", "doc:select-none" }`. The first
closes an open prompt; the second clears a selection. Neither competes with the
other, which is the point of the chain form.

### Jumping

| key | command | does |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>G</kbd> | `doc:go-to-line` | |

Type a number and it goes to that line. Type anything else and it fuzzy-matches
the document's lines, so a distinctive string is usually faster than counting.
This is one of the few places the runtime opens a prompt itself, and it is here
rather than in a plugin because a *line number* is a property of the document,
not a workflow layered on top of one.

## The editor

Always available. These are the whole of what the runtime does outside a
document, and the line drawn is deliberate: **could this work without any input
from the user?** `core:new-doc` can, so it is here. Anything that prompts for a
path is a workflow, and workflows live in plugins.

| key | command | does |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>N</kbd> | `core:new-doc` | an empty document in the active pane |
| <kbd>Alt</kbd>+<kbd>Return</kbd> | `core:toggle-fullscreen` | |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd> | `core:open-log` | the log view — see [The log](#the-log) |
| | `core:quit` | asks before discarding unsaved changes |
| | `core:force-quit` | does not ask |
| | `core:open-log` | the log view |

**`core:new-doc` stays in the runtime** even though opening files does not. A new
empty document needs no extension, and the vim integrations and every plugin
that opens a document assume it exists. The empty state of the editor has to be
reachable with no plugins at all.

**`core:quit` is a seam, not a command.** It is the one function plugins wrap to
run on exit. `core:force-quit` is the unwrap target; a plugin that calls it while
wrapping `core:quit` skips its own confirmation, which is why the pair exists. See
[the extension contract](../architecture/extension-contract.md#what-the-runtime-hands-you).

## Panes and splits

Available unless the active pane has a locked size, which is how the plugin
manager panel stays full-width while it is open.

| key | command | does |
| --- | --- | --- |
| <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>J</kbd> | `root:split-left` | |
| <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd> | `root:split-right` | |
| <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>I</kbd> | `root:split-up` | |
| <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>K</kbd> | `root:split-down` | |
| <kbd>Alt</kbd>+<kbd>J</kbd> / <kbd>L</kbd> / <kbd>I</kbd> / <kbd>K</kbd> | `root:switch-to-…` | focus the neighbouring pane in that direction |
| <kbd>Ctrl</kbd>+<kbd>W</kbd> | `root:close` | close the active view |
| <kbd>Ctrl</kbd>+<kbd>PageUp</kbd> / <kbd>PageDown</kbd> | `root:move-pane-view-…` | reorder views inside the pane |
| <kbd>Alt</kbd>+<kbd>1</kbd> … <kbd>Alt</kbd>+<kbd>9</kbd> | `root:switch-to-pane-view-1` … `-9` | |

Also registered, unbound by default:

| command | does |
| --- | --- |
| `root:switch-to-previous-pane-view` / `root:switch-to-next-pane-view` | cycle within the pane, wrapping |
| `root:shrink` / `root:grow` | move the divider 0.1 toward this pane |
| `root:split-{left,right,up,down}` | the four splits, by name |

**A pane holds several views; the layout is a tree.** `root:switch-to-pane-view-N`
reaches view *N inside the active pane*, which is not the same as tab N —
tabs are a cdin-x plugin with its own concept, and the two used to share a word.
The runtime's names are the `-pane-view-` ones for that reason. The old
`-tab-` spellings are still registered as aliases so existing keymaps keep
working:

```
root:switch-to-previous-tab   =  root:switch-to-previous-pane-view
root:switch-to-next-tab       =  root:switch-to-next-pane-view
root:move-tab-left            =  root:move-pane-view-left
root:move-tab-right           =  root:move-pane-view-right
root:switch-to-tab-1 … -9     =  root:switch-to-pane-view-1 … -9
```

They are the same function objects, not wrappers, so binding one and running it
is indistinguishable from binding the other.

**`root:split-*` re-opens the document in the new pane.** Splitting a document
pane and being left with a blank one on one side is never what anyone wanted, so
the active view is carried across. Splitting a non-document pane does nothing
extra.

**Focus is geometric, not ordered.** `root:switch-to-…` looks for the pane
overlapping a point just past the active pane's edge, which is why it works for
an uneven tree and why it refuses to move into a pane with a locked size.

## Prompts

Available while `core.command_view` is open. This is the one prompt primitive in
the runtime, and plugins build on it rather than each rolling their own.

| key | command | does |
| --- | --- | --- |
| <kbd>Return</kbd>, <kbd>Keypad Enter</kbd> | `command:submit` | run the current suggestion |
| <kbd>Tab</kbd> | `command:complete` | accept the highlighted suggestion |
| <kbd>Esc</kbd> | `command:escape` | close the prompt |
| <kbd>↑</kbd> / <kbd>↓</kbd> | `command:select-previous` / `command:select-next` | move through suggestions |

Every one of these is a **fallback chain** with a document command, which is why
<kbd>Return</kbd> and <kbd>Tab</kbd> work everywhere:

```
return         →  { "command:submit",      "doc:newline" }
keypad enter   →  { "command:submit",      "doc:newline" }
tab            →  { "command:complete",    "doc:indent"   }
up             →  { "command:select-previous", "doc:move-to-previous-line" }
down           →  { "command:select-next",     "doc:move-to-next-line"     }
escape         →  { "command:escape",      "doc:select-none"            }
```

## The log

Opened by <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd>, which is `core:open-log`.
That binding is the runtime's own: the log view is a core view, so the key that
opens it is core's. It used to have none, and that made the log unreachable in
a bare editor — the palette is a plugin, so with nothing installed there was no
route to it and no error either.

| key | command | does |
| --- | --- | --- |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd> | `core:open-log` | the log view, in the active pane |
| <kbd>Ctrl</kbd>+<kbd>C</kbd> | `log:copy-selection` | copies the selected log lines to the clipboard |
| <kbd>Ctrl</kbd>+<kbd>A</kbd> | `log:select-all` | selects the whole log |
| <kbd>F2</kbd> | `log:switch-source` | switches between the two streams |
| <kbd>Ctrl</kbd>+<kbd>R</kbd> | `log:reload` | re-reads the current one |

`<kbd>Ctrl</kbd>+<kbd>C</kbd>` and <kbd>Ctrl</kbd>+<kbd>A</kbd> are bound in
this view *in addition to* their document bindings, and the log wins because it
is the active view. This is the predicate doing its job, not an override.

### Two streams, and which one you want

| source | what is in it | where it comes from |
| --- | --- | --- |
| **editor** | every `core.log` / `core.error`, with tracebacks | `core.log_items`, the last `config.max_log_items` of them |
| **native** | C-level diagnostics and boot failures | the C logger's file, next to the binary |

**A plugin error only ever appears in the editor stream.** No Lua output
reaches the file, so do not go looking there for a plugin traceback — and the
file is the only place a crash *before* the editor existed is written, which is
why it is worth a keystroke. <kbd>F2</kbd> switches; the header names the file
and its line count, and <kbd>Ctrl</kbd>+<kbd>R</kbd> re-reads it, because a file
being appended to while you read it is not a snapshot.

The file is bounded and readable by default: `CDIN_LOG_LEVEL` sets the console
level, `CDIN_LOG_FILE_LEVEL` the file's, `CDIN_LOG_FILE` the path, and a log
past 4 MB is rotated to `cdin-log.txt.1` at startup rather than growing forever.
The file defaults to `DEBUG`, which drops the per-frame renderer traces that
used to fill it.

## The empty view

Always available. Shown when a pane has no document.

| command | does |
| --- | --- |
| `empty-view:open-file` | delegates to `core:open-file` |
| `empty-view:open-folder` | delegates to `core:open-folder` |
| `empty-view:open-recent-files` | whatever picker the recent provider wants |
| `empty-view:open-recent-dirs` | the same, for directories |

**All four are no-ops on a bare editor.** The first two delegate to
`core:open-file` and `core:open-folder` by name, and both belong to cdin-x's
finder plugin. `command.perform` on an unregistered name returns `false` and does
nothing, so with no plugin installed they do nothing rather than erroring — which
is the behaviour the empty view wants, since a dead entry on the start screen is
worse than a missing one.

The recent pair goes through `core.recent_provider` rather than a plugin command
name, and no provider is registered by default, so they are no-ops too. They open
whatever the registered provider wants to show, or nothing.

**None of the four is bound to a key in the runtime.** They are reachable from
the palette — which is itself a plugin, so on a bare editor, from anywhere.

On the empty view itself:

| key | does |
| --- | --- |
| <kbd>↑</kbd> / <kbd>↓</kbd> | navigate recent items |
| <kbd>Tab</kbd> | switch between files and directories |
| <kbd>Return</kbd> | open the selected item |
| <kbd>Esc</kbd> | clear the selection |
| <kbd>Ctrl</kbd>+<kbd>N</kbd> | new document |

Those five are the whole core-owned quick reference printed on that screen, and
they are deliberately short. The palette, find file, open file and open folder
are *not* listed, because printing a keystroke that does nothing on an editor
with no extensions is a lie the user has to debug. Installed plugins append
their own entries through `core.register_help_shortcuts`, so the list on screen
is always exactly as long as what actually works.

## Plugins

Always available. These three are commands, not a manager: there is no plugin
manager in *this* repository.

| command | does |
| --- | --- |
| `core:list-plugins` | what is on disk in both roots, and which of it is loaded |
| `core:load-plugin <name>…` | load by name, whatever `config.plugins` said |
| `core:unload-plugin <name>…` | run its `unload()` and forget it |

They take a **comma-separated list**, so `core:load-plugin a,b,c` works. With no
argument they report what to do instead — `core:list-plugins` for the first —
rather than failing silently.

**These are the `:packadd` case.** `config.plugins` decides what loads on its
own; naming a plugin explicitly is how a bare editor stays *useful* rather than
merely empty. It is deliberately not gated on the site set being enabled, so
`config.plugins = false` still leaves you a way to bring one thing in.

**They are not how you manage extensions.** A build carries the extension
manager, which is the panel you actually browse: it lists, searches, groups by
category, enables, disables, installs and removes, and it is in every build
because it is `essential` in
[cdin-x](https://github.com/m-mdy-m/cdin-x). <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd>
opens it (<kbd>M</kbd> in vim normal mode), and it keeps working with no cdin-x
installed — the catalog is then just the set the build ships, which is a truthful
answer rather than an empty panel. See
[plugins](../guides/plugins.md#the-manager) for what it can install.


**Nothing here persists.** There is no registry, no manifest and no saved
state: what you load this way is gone at exit, and the only thing that survives
a restart is what `config.plugins` asks for. Persistence is cdin-x's job, and
it is a job worth doing in a package manager rather than in the runtime.

## Binding your own

```lua
-- ~/.config/cdin/user/init.lua
local keymap = require "core.input.keymap"
keymap.add { ["ctrl+g"] = "doc:go-to-line" }
```

Your file runs **before** any plugin, and `keymap.add` **prepends**. So the
ordering that actually holds is:

- the runtime's default keymap is installed first, then
- your `init.lua`, then
- each plugin as it loads — each prepending in front of what is there

Which means **a plugin's binding wins over yours.** You are not protected by
load order; you are at the bottom of the stack. The way to beat a plugin is to
replace the binding outright, not to set it again:

```lua
keymap.add({ ["ctrl+d"] = "doc:select-lines" }, true)   -- drops everything else on ctrl+d
```

Without the `true`, your command is prepended and the existing chain survives
behind it — which is usually what you want (yours runs when its predicate holds,
and the old one still works otherwise) and occasionally a surprise. That is why
the flag is written at every call site in the tree rather than defaulted.

**This is the whole reason your file runs where it does.** Running it *last* would
make it impossible for a plugin to bind a key you had already claimed, and cdin-x
has no way to know which of your bindings it should respect.

To unbind, hand back the same shape:

```lua
keymap.remove { ["ctrl+d"] = "doc:select-lines" }
```

It detaches only the named commands, so another plugin bound to the same stroke
keeps working.

## Files

| file | holds |
| --- | --- |
| [`data/core/commands/`](../../data/core/commands) | every command, one file per group |
| [`data/core/keymaps/default.lua`](../../data/core/keymaps/default.lua) | every default binding |
| [`data/core/input/command.lua`](../../data/core/input/command.lua) | the registry, the predicates, `perform` |
| [`data/core/input/keymap.lua`](../../data/core/input/keymap.lua) | key resolution and the chain rule |
| [`data/core/views/commandview.lua`](../../data/core/views/commandview.lua) | the prompt primitive |
