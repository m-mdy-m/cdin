# Getting started

cdin is a small text editor in C and Lua. The C side owns the window, the
renderer and the OS; everything you would call "the editor" — documents, views,
commands, the keymap, syntax highlighting, styling — is Lua in `data/core/`
next to the binary. If you can read Lua, you can read the whole editor.

This page covers running it and finding your way around. To compile it, see
[building from source](building.md).

## Running

Download a release, or build it — with one caveat:

```sh
git clone https://github.com/m-mdy-m/cdin-x   # the mandatory set lives here
git clone https://github.com/m-mdy-m/cdin
cd cdin
make run
```

**A fresh clone of cdin alone cannot `make`.** `make` assembles `data/`, and the
mandatory set — vim mode, the extension manager, the default theme, the fonts —
comes from cdin-x, which must be a sibling checkout or be named with `CDINX_DIR`. `make bin` compiles the
binary alone and needs neither. [Building from source](building.md) has the whole
story.

The binary lands at `build/<platform>-<build>/cdin` — `cdin.exe` on Windows — and
that directory is self-contained. `data/` has to travel with it, which is the one
thing to be careful about if you move the binary somewhere.

You can pass files and a directory:

```sh
cdin notes.md src/          # open some files, work in src/
cdin --no-plugins notes.md  # site plugins off; vim and the manager stay
cdin -u NONE notes.md       # the same thing, vim's spelling
```

A directory argument becomes the working directory, and the working directory
*is* the project: the file list, the ignore rules and the git status all come from
it. With no directory, the last one you used is restored — cdin-x's session
plugin writes it, and with no session file it falls back to the executable's own
directory.

Careful with `-u`: it swallows the *next* argument unconditionally, so
`cdin -u notes.md` opens nothing and you get an empty editor.

`--no-plugins` turns off **site** plugins only — the directory a cdin-x checkout
and your own plugins live in. Vim mode, the manager, the default theme and the
fonts are part of the build and always load, and what you installed *from the
panel* is in neither place, so it keeps loading too. See
[configuration](configuration.md#plugins) for the whole boundary.

## First launch

You get the empty view: recent files and directories, and a short quick
reference underneath.

| key | does |
| --- | --- |
| <kbd>Ctrl</kbd>+<kbd>N</kbd> | a new empty document |
| <kbd>↑</kbd> / <kbd>↓</kbd> | move through the recent items — *printed, but not wired yet* |
| <kbd>Tab</kbd> | switch between files and directories — *printed, but not wired yet* |
| <kbd>Return</kbd> | open the selected one — *printed, but not wired yet* |
| <kbd>Esc</kbd> | clear the selection — *printed, but not wired yet* |

Clicking a recent item opens it. The four struck-through rows are a known gap,
not a design: the empty view handles those keys in an `on_key_pressed` that
nothing in the runtime calls, and the commands those strokes name all need an open
prompt. [Commands](commands.md#the-empty-view) has the mechanism; it is a
two-line dispatch and it is the one thing on this screen that lies to you.

There is no command palette row, no "find file" row, no "open folder" row —
**those features are not part of this editor**, so listing them would print
keystrokes that do nothing. Install the extensions that provide them and their
entries appear here, appended, so the list on screen stays exactly as long as
what the runtime owns.

With no document open, <kbd>Ctrl</kbd>+<kbd>N</kbd> is the whole editor. It works
with nothing installed, which is the test that the two halves of this project are
really separate.

## What you get, and what you have to add

**In every build, because the editor cannot start without them:**

| | |
| --- | --- |
| **vim mode** | modal editing and the `:` line. <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>V</kbd> toggles it for the session — both the key and the setting belong to the vim plugin, not to the runtime |
| **the extension manager** | the panel that lists, searches, installs and removes extensions. <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> |
| **the `default` theme** | |
| **the fonts** | the text pipeline has nothing to render with otherwise |

The manager is in every build because "what is installed, and how do I change
that" is a question the editor has to be able to answer itself. Everything it
offers is still optional; what is not optional is the ability to ask. With no
cdin-x installed it lists exactly what the build carries, which is a truthful
answer rather than an empty panel.

**Not in the build, because they are workflows rather than mechanics.** None of
these keystrokes works until you install the thing that owns it:

| | binds | for |
| --- | --- | --- |
| **command palette** | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> | run any command by name |
| **finder** | <kbd>Ctrl</kbd>+<kbd>P</kbd>, <kbd>Ctrl</kbd>+<kbd>O</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd> | find a file, open a path, open a folder |
| **project tree** | <kbd>Ctrl</kbd>+<kbd>\\</kbd>, <kbd>F3</kbd> | show and focus it |
| **tabs** | <kbd>Ctrl</kbd>+<kbd>Tab</kbd>, <kbd>Ctrl</kbd>+<kbd>T</kbd> | switch, create |
| **find and replace** | <kbd>Ctrl</kbd>+<kbd>F</kbd> | in the document |
| **project-wide search** | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>F</kbd> | across files |
| **session restore** | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> | recent files |
| **git** | *no keys* | status in the tree and the status bar |
| **syntax highlighting** | *no keys* | one extension per language, six to start with |
| **themes** | *no keys* | nine more beyond `default` |

Plus autocomplete, the vim integrations, and cdin-x's `optional/` trio.

**Splits and panes are the exception, and they are the runtime's.**
<kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>J</kbd>/<kbd>L</kbd>/<kbd>I</kbd>/<kbd>K</kbd>
splits, <kbd>Alt</kbd>+<kbd>J</kbd>/<kbd>L</kbd>/<kbd>I</kbd>/<kbd>K</kbd> moves
between panes, and <kbd>Ctrl</kbd>+<kbd>W</kbd> closes a view — because laying out
a window needs no extension. cdin-x's `window` extension adds an alternative set
(<kbd>Alt</kbd>+<kbd>h/j/k/l</kbd>, <kbd>Ctrl</kbd>+<kbd>\\</kbd>) and, where the
two overlap, it wins: <kbd>Alt</kbd>+<kbd>J</kbd> will do what `window` says.

All of it is [cdin-x](https://github.com/m-mdy-m/cdin-x), and you get it from
inside the editor. Press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd>, move to
what you want, press <kbd>Space</kbd>. The manager downloads that one extension —
not the repository — and loads it without a restart. [Extensions](extensions.md)
has every key, what each one collides with, what is downloaded, and where it
goes.

You need a cdin-x checkout to *build* cdin, and not to use it. Cloning one and
running `make link` is for working on cdin-x itself: it puts the checkout into
your site directory so your edits are live.

**If you only want one thing**, it is the command palette — it runs every command
in this reference by name, which is the fastest way to learn what exists. Find
`palette` in the panel and press <kbd>Space</kbd>. `finder` is the second: three
keys for the three ways of getting a file open, and the empty view delegates to it
by name, so installing it is what makes "open file" on the start screen work.

## The parts you will use every day

**Moving and editing.** Arrow keys, <kbd>Ctrl</kbd> for word-at-a-time,
<kbd>Ctrl</kbd>+<kbd>←</kbd>/<kbd>→</kbd> for words, <kbd>Ctrl</kbd>+<kbd>[</kbd>/<kbd>]</kbd>
for bracketed blocks, <kbd>Home</kbd>/<kbd>End</kbd> for the line,
<kbd>Ctrl</kbd>+<kbd>Home</kbd>/<kbd>End</kbd> for the file. Selections are
<kbd>Shift</kbd> plus any of those. <kbd>Tab</kbd> indents,
<kbd>Shift</kbd>+<kbd>Tab</kbd> outdents, <kbd>Ctrl</kbd>+<kbd>/</kbd> toggles
comments.

**Saving.** <kbd>Ctrl</kbd>+<kbd>S</kbd>, which prompts for a path the first time.
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> saves under a different name.

**Splitting.** <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>J</kbd>/<kbd>L</kbd>/<kbd>I</kbd>/<kbd>K</kbd>
splits the pane in that direction, <kbd>Alt</kbd>+<kbd>J</kbd>/<kbd>L</kbd>/<kbd>I</kbd>/<kbd>K</kbd>
moves between panes, <kbd>Ctrl</kbd>+<kbd>W</kbd> closes the active view.
Splitting carries the current document into the new pane, so you never end up
staring at half a split.

**Jumping.** <kbd>Ctrl</kbd>+<kbd>G</kbd> takes a line number, or a string to
fuzzy-match against the document's lines — so a distinctive phrase is usually
faster than counting.

**Quitting.** Any command runner's quit, or close the window. You are asked before
discarding unsaved changes.

[the command reference](commands.md) has all of it, with the command name for
each.

## Configuring

One file:

```
~/.config/cdin/user/init.lua
```

```lua
local keymap = require "core.input.keymap"
keymap.add { ["ctrl+g"] = "doc:go-to-line" }
```

`config` and `core` are **not** globals — the editor raises on any undeclared
global, so `require` them:

```lua
local config = require "core.config"
config.indent_size = 4
```

Your file runs before plugins load. [Configuration](configuration.md) has every
key, and the reasoning behind the load order — which decides whether a plugin or
you gets the last word on a keystroke.

## When something does not work

Press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd>, which is `core:open-log`. The
runtime binds it itself, so it works in a build with nothing installed.

Everything the log view shows is also written to `cdin-log.txt` next to the
binary, together with the C logger's own lines, tracebacks included. That one
text file is what to attach to a bug report. See
[troubleshooting](troubleshooting.md#start-here).

[Troubleshooting](troubleshooting.md) has the specific failures, build and
otherwise, and a short list of `make` targets that do not work.

## Where to go next

| | |
| --- | --- |
| [Commands](commands.md) | every command and key, as a table |
| [Configuration](configuration.md) | every `config` key |
| [Extensions](extensions.md) | what a build contains, the panel, installing, where things land |
| [Plugins](plugins.md) | the loader, and writing one |
| [Architecture](../architecture/overview.md) | if you are about to change something |
| [Extension contract](../architecture/extension-contract.md) | if you are about to change what is guaranteed |
