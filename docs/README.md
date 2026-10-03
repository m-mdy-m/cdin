# Documentation

Ten pages. Most people need two of them.

## Two repositories, and the line between them

**cdin** is the editor runtime: the window, the renderer, the text pipeline, the
document, the views, the command and key registries. Its `data/` holds only
`core/`. `make bin` compiles it with nothing else present.

**[cdin-x](https://github.com/m-mdy-m/cdin-x)** is everything the runtime
deliberately does not have: the command palette, the file finders, the project
tree, tabs, find-and-replace, git, the themes beyond `default`, the syntax
definitions, and vim mode.

Exactly four things cross that line, and each has a reason:

| | |
| --- | --- |
| **vim mode** | bundled into the build, not installed beside everything else, because an editor with no modal editing is not an editor |
| **the extension manager** | bundled for the same reason: "what is installed, and how do I change that" is a question the editor has to answer itself. Everything it *offers* stays optional |
| **the `default` theme** | a build has to be able to start, and it has to have something to start with |
| **the fonts** | the text pipeline has nothing to render with without them |

**To build** cdin you need a cdin-x checkout beside it, because `make` assembles
the four from there. **To use** it you do not: the manager downloads one index
file and then the extensions you pick. A cdin with nothing installed still starts,
renders, edits, and answers <kbd>Ctrl</kbd>+<kbd>N</kbd>.

That is why <kbd>Ctrl</kbd>+<kbd>P</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd>,
<kbd>Ctrl</kbd>+<kbd>O</kbd> and <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd>
are **not** bound by this runtime, and why
[the command reference](guides/commands.md) does not list them. They belong to
the plugins that implement them, so that an editor with no extensions has no
dead keys and an editor with them gets them from the thing that actually works.
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> and <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd>
are bound, because the manager and the log view are part of every build.

[Extensions](guides/extensions.md) has the whole list: every optional extension,
the keys each one adds, and the handful of strokes where two of them overlap.

## Using it

**[Getting started](guides/getting-started.md)** — install, first launch, what
you get out of the box and what you have to add. If you read one page, read
that one.

**[Extensions](guides/extensions.md)** — what a build contains, the
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> panel, what installing downloads, and
where everything ends up on disk.

**[Configuration](guides/configuration.md)** — every `config` key, what it
defaults to, and the one that decides where your plugins live.

**[Commands](guides/commands.md)** — every command the runtime registers and
every key it binds, as tables you can copy from.

## Writing an extension

**[Plugins](guides/plugins.md)** — the loader, the two roots, the error policy,
the seams, and writing one.

## Building it

**[Building from source](guides/building.md)** — dependencies, the `make`
targets, the `CDINX_DIR` a build needs, and the four test suites.
**[Troubleshooting](guides/troubleshooting.md)** — build failures, and the ones
that are not build failures.

## Working on the editor

**[architecture/overview.md](architecture/overview.md)** — the C/Lua split and
the boot order. Read this one first if you are about to change anything.
**[architecture/internals.md](architecture/internals.md)** — the frame loop, the
text pipeline, the highlighter and tokenizer, the view tree.
**[architecture/extension-contract.md](architecture/extension-contract.md)** —
the whole of what cdin guarantees an extension, and therefore the whole of what
cdin-x is allowed to assume. If something is not in there, it is not a contract,
and changing it is a breaking change.

**[CONTRIBUTING.md](../CONTRIBUTING.md)** — the conventions and the PR checklist.
**[AGENTS.md](../AGENTS.md)** — the same, for agents: which suite to run after
touching what.

## Elsewhere

vim mode, the palette, the finders, the tree, tabs, search, git, the themes, the
syntax definitions, and the manager's own panel are documented in
[cdin-x](https://github.com/m-mdy-m/cdin-x), which is where the code for them
lives — so that an extension's documentation changes when its code does. Start at
its [getting started](https://github.com/m-mdy-m/cdin-x/blob/main/docs/getting-started.md).

| you want | read |
| --- | --- |
| every vim key, motion and ex-command | [the vim page](https://github.com/m-mdy-m/cdin-x/blob/main/docs/plugins/vim.md) |
| the manager's panel, key by key | [the manager page](https://github.com/m-mdy-m/cdin-x/blob/main/docs/plugins/manager.md) |
| to write a theme | [adding a theme](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-theme.md) |
| to add a language | [adding a syntax definition](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-syntax-definition.md) |
| to write a plugin | [writing a plugin](https://github.com/m-mdy-m/cdin-x/blob/main/docs/writing-a-plugin.md) |
| to extend vim mode | [extending vim](https://github.com/m-mdy-m/cdin-x/blob/main/docs/extending-vim.md) |
| what one plugin does | [the plugin index](https://github.com/m-mdy-m/cdin-x/blob/main/docs/plugins/README.md) |

## The short version

```sh
make                  # binary + the bundled data/ → build/<platform>-release/
                      # needs a cdin-x checkout beside this one
make bin              # the binary only; no cdin-x needed
make info             # what was detected, and where it will go
make test-plugins     # keymap + loader; needs only lua
make test-workflows   # the cdin-x half; needs lua + CDINX_DIR
```

```lua
-- ~/.config/cdin/user/init.lua
local keymap = require "core.input.keymap"
keymap.add { ["ctrl+g"] = "doc:go-to-line" }
```
