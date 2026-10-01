# Documentation

Twelve pages. Most people need two of them.

## Two repositories, and the line between them

**cdin** is the editor runtime: the window, the renderer, the text pipeline, the
document, the views, the command and key registries. Its `data/` holds only
`core/`. A checkout of it builds and runs on its own.

**[cdin-x](https://github.com/m-mdy-m/cdin-x)** is everything the runtime
deliberately does not have: the command palette, the file finders, the project
tree, tabs, find-and-replace, git, the themes beyond `default`, the syntax
definitions, and vim mode.

Exactly three things cross that line, and each has a reason:

| | |
| --- | --- |
| **vim mode** | bundled into the build, not installed beside everything else, because an editor with no modal editing is not an editor |
| **the `default` theme** | a build has to be able to start, and it has to have something to start with |
| **the fonts** | the text pipeline has nothing to render with without them |

Everything else is optional, and a cdin with no extensions installed still
starts, renders, edits, and answers <kbd>Ctrl</kbd>+<kbd>N</kbd>.

That is why <kbd>Ctrl</kbd>+<kbd>P</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>
and <kbd>Ctrl</kbd>+<kbd>O</kbd> are **not** bound by this runtime, and why
[the command reference](guides/commands.md) does not list them. They belong to
the plugins that implement them, so that an editor with no extensions has no
dead keys and an editor with them gets them from the thing that actually works.

## Using it

**[Getting started](guides/getting-started.md)** — install, first launch, what
you get out of the box and what you have to add. If you read one page, read
that one.

**[Configuration](guides/configuration.md)** — every `config` key, what it
defaults to, and the one that decides where your plugins live.

**[Commands](guides/commands.md)** — every command the runtime registers and
every key it binds, as tables you can copy from.

## Using one part of it

| page | for |
| --- | --- |
| [Themes](guides/themes.md) | every colour in the editor, and writing your own |
| [Syntax highlighting](guides/syntax.md) | how a language gets coloured, and writing a definition |
| [Vim mode](guides/vim-keybindings.md) | what the runtime contributes, and where the rest is documented |
| [Plugins](guides/plugins.md) | the loader, the site directory, and writing one |

## Building it

**[Building from source](guides/building.md)** — dependencies, the `make`
targets, and the `CDINX_DIR` a build needs.
**[Troubleshooting](guides/troubleshooting.md)** — build failures, and the ones
that are not build failures.

## Working on the editor

**[architecture/overview.md](architecture/overview.md)** — the C/Lua split and
the boot order. Read this one first if you are about to change anything.
**[architecture/internals.md](architecture/internals.md)** — the frame loop, the
text pipeline, the view tree.
**[architecture/extension-contract.md](architecture/extension-contract.md)** —
the whole of what cdin guarantees an extension, and therefore the whole of what
cdin-x is allowed to assume. If something is not in there, it is not a contract,
and changing it is a breaking change.

**[CONTRIBUTING.md](../CONTRIBUTING.md)** — what `make check` enforces and why.
**[scripts/README.md](../scripts/README.md)** — the four test suites and what
each one actually asserts.

## Elsewhere

vim mode, the palette, the finders, the tree, tabs, search, git, the themes, the
syntax definitions and the extension manager are all documented in
[cdin-x](https://github.com/m-mdy-m/cdin-x), which is where the code for them
lives. Start at its
[getting started](https://github.com/m-mdy-m/cdin-x/blob/main/docs/getting-started.md).

## The short version

```sh
make                  # binary + the bundled data/ → build/<platform>-release/
make bin              # the binary only; no cdin-x checkout needed
make info             # what was detected, and where it will go
make check            # every test suite
```

```lua
-- ~/.config/cdin/user/init.lua
local keymap = require "core.input.keymap"
keymap.add { ["ctrl+g"] = "doc:go-to-line" }
```
