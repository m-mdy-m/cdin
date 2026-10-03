# Extensions

cdin is the editor runtime. Everything that is a *workflow* rather than a
*mechanism* — the command palette, the file finders, the project tree, tabs,
search, git, vim mode, themes, language definitions — is an extension, and the
extensions live in [cdin-x](https://github.com/m-mdy-m/cdin-x).

This page is the user's view of that arrangement: what is already in your
build, how to get the rest, and where it all ends up on disk. How the loader
works is [plugins](plugins.md); what cdin guarantees an extension is
[the extension contract](../architecture/extension-contract.md).

## What every build contains

Four things, and nothing else crosses the repository line:

| | what it is | why it is not optional |
| --- | --- | --- |
| **vim mode** | modal editing and the `:` line | an editor with no modal editing is not what this project builds |
| **the extension manager** | the panel that lists, searches, installs and removes extensions | "what is installed, and how do I change that" is a question the editor has to answer itself |
| **the `default` theme** | one theme | a build has to be able to start, and it needs something to start with |
| **the fonts** | the text pipeline's only input | nothing renders without them |

**Three of the four are extensions and one is not.** vim, the manager and the
`default` theme carry `essential = true` in cdin-x — that is the marker, and
exactly three entries in the whole catalog carry it: `vim`, `manager`, `default`.
It is the bundler's entire selection rule, read as text out of each entry point
rather than executed, and adding a fourth is a deliberate act rather than an
accident. The fonts are not a plugin at all, which is why the bundler checks them
separately and fails on an empty `fonts/`.

vim and the manager are *bundled plugins*: they load on every start, whatever
`config.plugins` or `--no-plugins` say. The manager's own code travels with it
(`cdinx/` in the build's `data/`), because it lives at the root of cdin-x rather
than under `X/`.

Everything the manager *offers* is still optional. What is not optional is being
able to ask.

**A build with no extensions installed is a working editor.** It starts, renders,
edits, answers <kbd>Ctrl</kbd>+<kbd>N</kbd>, and has vim keys and a panel. It has
no command palette, no finders and no tree, and it does not pretend to: a key
that would do nothing is not bound, and the empty view only lists what works.
It also has no syntax highlighting — the *mechanism* is the runtime's, but the
language definitions are extensions, so a bare build shows every file as plain
text until you install some.

**A build's entire cdin-x keystroke inventory is two keys**:
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> for the panel, and
<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>L</kbd> for the log. Everything else you
press on a fresh build is the runtime's own — which is why
[the command reference](commands.md) can be a complete list.

## What is not in the build, and what each one binds

Every key in the first block below is **absent on a fresh build**. They are listed
because they are the reason to install the thing, and because knowing a key is not
there yet is the difference between a missing feature and a bug. The last two rows
are the exception — they are in every build, and are here so the table is one
lookup rather than two.

| extension | binds | for |
| --- | --- | --- |
| `palette` | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> | run any command by name |
| `finder` | <kbd>Ctrl</kbd>+<kbd>P</kbd> · <kbd>Ctrl</kbd>+<kbd>O</kbd> · <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>O</kbd> | find a file · open a path · open a folder |
| `treeview` | <kbd>Ctrl</kbd>+<kbd>\\</kbd> · <kbd>F3</kbd> · <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>E</kbd> · <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>N</kbd> · <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>N</kbd> · <kbd>F2</kbd> · <kbd>Ctrl</kbd>+<kbd>R</kbd> · <kbd>Del</kbd> | show · focus · new file · new directory · rename the item under the cursor · rename · delete |
| | also <kbd>↑</kbd> <kbd>↓</kbd> <kbd>Return</kbd> <kbd>←</kbd> <kbd>→</kbd> | navigate, open, collapse, expand — only while the tree has focus |
| `tab` | <kbd>Ctrl</kbd>+<kbd>Tab</kbd> · <kbd>Ctrl</kbd>+<kbd>T</kbd> · <kbd>Ctrl</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | next tab · new tab · go to tab N |
| `window` | <kbd>Alt</kbd>+<kbd>h/j/k/l</kbd> · <kbd>Ctrl</kbd>+<kbd>\\</kbd> · <kbd>Alt</kbd>+arrows | focus, split, resize — **see the collision note below** |
| `search` | <kbd>Ctrl</kbd>+<kbd>F</kbd> · <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>F</kbd> · <kbd>F4</kbd> · <kbd>F5</kbd> | find-replace · project search · repeat · refresh |
| `session` | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> · <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>D</kbd> · <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>S</kbd> | recent files · recent folders · save |
| `autoupdate` | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>U</kbd> | check GitHub for a newer release |
| `git` · `menu` · `modules` | *nothing* | see below |
| `vim` | <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>V</kbd> | **in the build** — toggles vim mode for the session |
| `manager` | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> | **in the build** — this panel |

**`git`, `menu` and `modules` bind nothing at all.** Git shows its status in the
treeview and the status bar through `core.register_vcs_provider`; `menu` is the
shared menu machinery the other extensions build on; `modules` opens its pickers
by name. None wants a keystroke of its own, which is why they are the three rows
with an empty middle column.

The catalog is **45 entries**: 16 core plugins — `autocomplete`, `autoreload`,
`autoupdate`, `finder`, `git`, `manager`, `menu`, `modules`, `palette`, `search`,
`session`, `tab`, `treeview`, `trimwhitespace`, `vim`, `window` — plus 10
integrations, 6 language definitions, 3 optional and 10 themes. Of the 16, exactly
two are in a build: `manager` and `vim`. The panel can also group by LSP,
Formatters, Debug, Utilities and Interface; those categories are in the table and
currently empty, which is where a new extension goes.

Three more are worth a line because they add no key of their own and are easy to
miss when you install them and nothing appears:

| | what it does instead |
| --- | --- |
| `autoreload` | notices a file changed on disk and offers to reload it. No key; the offer appears when you focus the document |
| `trimwhitespace` | strips trailing whitespace on every save, through `Doc._before_save`. No key by design — it has no opinion you can have |
| `autocomplete` | pops up while you type, and takes over <kbd>Tab</kbd>, <kbd>↑</kbd>, <kbd>↓</kbd> and <kbd>Esc</kbd> — the runtime's own keys — but only while the popup is visible, so they mean indent, cursor movement and deselect the rest of the time |

An **integration** is the wiring *between* capabilities: `git-treeview`,
`session-theme-switcher`, `tab-session`, and seven `vim-*` that give vim mode
access to git, the menu, search, tabs, the tree, the window manager and the
manager panel. They exist because the thing they connect lives in two places, and
that is also why they are the extensions you are most likely to need only after
installing the other half — `vim-plugin-manager` is the one named on this page,
since that is what makes <kbd>Shift</kbd>+<kbd>M</kbd> work.

**Some of these collide, and it is worth knowing before you install two of them.**
`keymap.add` prepends, so the extension loaded later wins and the earlier one
stays behind it as a fallback rather than disappearing:

| stroke | the runtime's | also claimed by | effect |
| --- | --- | --- | --- |
| <kbd>Alt</kbd>+<kbd>J</kbd> / <kbd>K</kbd> / <kbd>L</kbd> | `root:switch-to-right` / `-up` / `-down` | `window`, as `window:focus-*` | whichever loaded last. Both mean "move" |
| <kbd>Ctrl</kbd>+<kbd>D</kbd> | `doc:select-word` | `search`, as `find-replace:select-next` | harmless: `search` only holds the key while a match is selected |
| <kbd>Ctrl</kbd>+<kbd>R</kbd> | `log:reload` | `treeview:rename-key` | **real.** <kbd>Ctrl</kbd>+<kbd>R</kbd> in the log is not "reload" once the tree is installed |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>D</kbd> | `doc:duplicate-lines` | `session:open-recent-dirs` | **real.** You lose duplicate-line |
| <kbd>F2</kbd> | `log:switch-source` | `treeview:toggle-key` | **real.** The log no longer switches streams |
| <kbd>Ctrl</kbd>+<kbd>\\</kbd> | *nothing* | `treeview:toggle` and `window:vsplit` | extension vs extension — the later one wins, and they do different things |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> | *nothing* | `session:open-recent` and `treeview:refresh-key` | the same, between two optional extensions |
| <kbd>↑</kbd> <kbd>↓</kbd> <kbd>Return</kbd> <kbd>←</kbd> <kbd>→</kbd> <kbd>Ctrl</kbd>+<kbd>C</kbd> <kbd>Ctrl</kbd>+<kbd>A</kbd> <kbd>Esc</kbd> <kbd>Tab</kbd> | the document, the prompt, the log | `autocomplete`, `search`, `treeview` | **not a collision** — see below |

The last row is the design working, and cdin-x knows it: `search`'s own keymap
carries a comment saying never to pass `overwrite` on <kbd>Ctrl</kbd>+<kbd>D</kbd>,
because replacing a whole chain is what once left the document with dead arrows
and the `:` prompt with a dead <kbd>Enter</kbd>. Every one of those bindings is
behind a predicate that requires its own view to be active, so each falls through
the moment you are somewhere else.

The rows marked **real** are two *unconditional* claims on one stroke, which is
the only kind that actually costs you something. There is no runtime binding you
can move to fix them — the answer is to rebind one in your `init.lua`, which runs
before every plugin and therefore wins:

```lua
keymap.add { ["ctrl+r"] = "log:reload" }
```

**A new binding should not create one.** Ask the question in
`data/core/commands/core.lua` before adding a stroke: could this work without any
input from the user? If it prompts for a path, it is a workflow and it belongs in
an extension — and then the runtime is right not to have bound it.

## The panel

<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> opens and closes it, from anywhere.

| key | does |
| --- | --- |
| <kbd>j</kbd> / <kbd>k</kbd>, <kbd>↓</kbd> / <kbd>↑</kbd> | move |
| <kbd>/</kbd> or <kbd>Ctrl</kbd>+<kbd>F</kbd> | search; type to filter |
| <kbd>Space</kbd> / <kbd>X</kbd> | enable or disable |
| <kbd>Return</kbd> | the same, for the entry under the cursor |
| <kbd>I</kbd> | install |
| <kbd>U</kbd> | remove |
| <kbd>D</kbd> | details |
| <kbd>R</kbd> | rescan the disk — no network |
| <kbd>?</kbd> | log where the catalog came from |
| <kbd>Ctrl</kbd>+<kbd>R</kbd> | download the catalog index again |
| <kbd>[</kbd> / <kbd>]</kbd> | narrower / wider |
| <kbd>Backspace</kbd> | delete a character, while searching |
| <kbd>Esc</kbd> | close (or, while searching, leave the search) |

The keys are lowercase, and there is no <kbd>q</kbd>:
<kbd>Esc</kbd> is the way out. While you are searching, letters are text.

<kbd>Shift</kbd>+<kbd>M</kbd> in vim normal mode does the same thing **only if**
cdin-x's `vim-plugin-manager` integration is installed. It is deliberately not a
global binding: a global <kbd>Shift</kbd>+<kbd>M</kbd> is also how you type a
capital `M`.

The list has three sections, in the order that answers "what is here, and what
is mine":

| section | holds | you can |
| --- | --- | --- |
| **In the editor** | what the build carries | see it. It is not the manager's to remove |
| **Installed** | what you put here | enable, disable, update, remove |
| **Available** | what the catalog offers | install |

Installed and available are grouped by category underneath, in a fixed order —
Core, Syntax, LSP, Formatters, Git, Debug, Interface, Utilities, Integrations,
Optional, Themes. Anything whose category is not in that table lands in **Other**,
alphabetically after the rest.

The title bar carries the counts — `2 in editor  0 installed  43 available` on a
fresh build, which is the two bundled plugins against a catalog of 45 entries.
While a search is running the counts are of what **matched**, not of what exists;
the right end of the filter line says `7 of 45` for the same reason.

The full key list, the search rules and the details menu are in
[cdin-x's manager page](https://github.com/m-mdy-m/cdin-x/blob/main/docs/plugins/manager.md),
which is where the code is.

## Installing

Pick something, press <kbd>Space</kbd> (or <kbd>I</kbd>). It is installed and
loaded in the same frame; there is no restart. If the extension declares
dependencies they install first, in order, and a dependency cycle is reported
rather than followed.

**Nothing is cloned and git is never used.** The network use is two things:

| when | what is downloaded |
| --- | --- |
| the first time the panel needs a catalog, and on <kbd>Ctrl</kbd>+<kbd>R</kbd> | one file, `X/manifest.lua` — the index, about 18 KiB. Searching reads only this |
| an install | exactly the files that entry lists, which for a plugin is its directory and for a theme is one `theme.lua` |

Files are downloaded into a staging directory and moved into place only after
the whole download succeeded, so a half-downloaded extension is never visible.
The downloader is `curl`, else `wget`, else PowerShell on Windows; the `curl`
path caps the transfer at 120 seconds, and all of it runs off the frame loop —
the editor stays usable.

So a build alone is enough: you do **not** need a cdin-x checkout to install
extensions, only to *build* cdin. You do need one of those three downloaders and
a network connection. With neither, the panel still lists what the build carries
and `?` says why the catalog is missing.

**A theme is the one thing that does not become a running plugin.** It is written
to the store as `<category>/<name>/theme.lua` and the panel lists it, but the
host's theme registry is only pointed at the build's own theme directory and at a
cdin-x checkout in the site directory — neither of which is the store. So in
0.2.0 a theme installed from the panel does not join the theme switcher, and
`config.theme` will not find it by name. Put it in `config.user_dir/themes` — the
first root the registry searches — until the manager registers its own.

## Where things end up

| | where | put there by |
| --- | --- | --- |
| the mandatory set | `EXEDIR/data/plugins`, `data/X`, `data/cdinx`, `data/themes`, `data/fonts` | the build, from a cdin-x checkout |
| extensions you installed from the panel | `<data_home>/cdin/extensions/X` | the manager |
| the catalog index | `<data_home>/cdin/registry/cdin-x/X/manifest.lua` | the manager |
| which extensions you disabled | `<data_home>/cdin/extensions.lua` | the manager |
| a cdin-x checkout installed with `make link` | the site directory, `<data_home>/cdin/site` | you |
| your own plugins | `config.site_path()/plugins` | you |

`<data_home>` is `$XDG_DATA_HOME` or `~/.local/share` on Linux and macOS, and
`%LOCALAPPDATA%`, then `%APPDATA%`, then `%USERPROFILE%\AppData\Local` on
Windows. cdin computes it once, in `config.data_home`; the manager recomputes the
same thing rather than reading that field, because it has to be able to run before
it has decided to trust anything. The site directory's *name* is
`config.site_dirname` ([configuration](configuration.md#where-things-live)).

**The first four rows are not the loader's business.** `core.plugins` knows two
roots — bundled and site — and nothing else. The manager finds what it installed
by itself, loads it itself, and makes it `require`able through a
`package.searchers` entry of its own placed *after* the standard searcher, so a
bundled copy still wins. The runtime never learns that an extension store exists.

**Two precedences, and they do not agree.** The runtime loader scans bundled
first and takes the first name it sees, so a bundled plugin beats a site plugin of
the same name. The manager merges what it finds in its own order — the catalog
index, then the store, then the build's bundle, then a cdin-x checkout in the
site directory — and the **last** root wins, because each one overwrites the one
before it. So a checkout you are working on takes precedence over a downloaded
copy of the same extension, which is what makes `make link` usable.

**Locking is a separate thing from precedence.** The panel lists what the build
carries under *in the editor* and refuses to enable, disable or remove it,
because it belongs to the build rather than to you.

### `make link` is for people working on cdin-x

Cloning cdin-x and running `make link` puts three directories — `cdinx/`, `X/`
and `plugins/cdin-x/` — into the site directory as symlinks, so edits to the
checkout are live. It is the development loop, not an installation step: a user
who only wants the palette presses <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd>
and installs it. Both can coexist. Where symlinks are unavailable the target says
so and copies instead, which is worth knowing on a Windows without developer mode
— you then have a copy, and running `make link` again will not update it.

## Turning it all off

| | |
| --- | --- |
| `--no-plugins`, `config.plugins = false` | no **site** plugins. The bundled set — vim, the manager — still loads, and so does everything the manager itself installed |
| a plugin's own toggle (<kbd>Space</kbd> in the panel) | that plugin only, and the choice persists |
| `config.vim_mode_enabled = false` | normal typing. <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>V</kbd> toggles it for a session |

**`--no-plugins` is not "turn the extensions off".** It selects the *site*
directory, which is where a cdin-x checkout and your own plugins live. What the
manager installed lives in the manager's own store and is loaded by the manager,
which never reads `config.plugins`. To stop one of those, disable it in the
panel; to stop all of them, delete the store.

Neither key is the runtime's: `config.vim_mode_enabled` is defined by cdin-x's
vim plugin, not by `data/core/config.lua`, and so is the stroke bound to it.

There is no setting that removes the manager or vim. A build that has neither is
not a cdin build, and the way to get one is to not build it.

## Where each extension is documented

Not here, on purpose: the code and the page that explains it change together.

| you want | read |
| --- | --- |
| to use an extension | [cdin-x docs/plugins](https://github.com/m-mdy-m/cdin-x/tree/main/docs/plugins) — one page each |
| every vim key, motion and ex-command | [the vim page](https://github.com/m-mdy-m/cdin-x/blob/main/docs/plugins/vim.md) |
| to write a theme | [adding a theme](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-theme.md) |
| to add a language | [adding a syntax definition](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-syntax-definition.md) |
| to write a plugin | [writing a plugin](https://github.com/m-mdy-m/cdin-x/blob/main/docs/writing-a-plugin.md) |
| to extend vim mode | [extending vim](https://github.com/m-mdy-m/cdin-x/blob/main/docs/extending-vim.md) |

What stays in *this* repository is the part that is the runtime's: the registry
a theme is read through (`core.themes`), the tokenizer a definition feeds
([internals](../architecture/internals.md#syntax-highlighting)), and the loader.
