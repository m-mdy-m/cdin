# Vim mode

Vim mode is a **bundled extension**, not part of the runtime. It lives in
[cdin-x](https://github.com/m-mdy-m/cdin-x) as `X/core/vim`, it is marked
`essential`, and a build copies it into `data/plugins/vim.lua`. It is loaded
before any site plugin and cannot be switched off with `config.plugins` or
`--no-plugins`, because an editor with no modal editing is not an editor.

**The full key set is documented in cdin-x**, which is where the code is:

- [the vim plugin page](https://github.com/m-mdy-m/cdin-x/blob/main/docs/plugins/vim.md) —
  every mode, motion, editing key and ex-command, and what is deliberately absent
- [extending vim mode](https://github.com/m-mdy-m/cdin-x/blob/main/docs/extending-vim.md) —
  the seven seams integrations register through

This page covers the half that belongs to cdin: what the runtime actually
contributes to vim mode, which is less than most people expect, and one setting
whose absence from the runtime is deliberate.

## What the runtime provides

**The motions are ordinary commands.** Every vim movement and editing key is a
`doc:*` command — `doc:move-to-previous-word-start`, `doc:select-to-next-line`,
`doc:join-lines`, `doc:delete-to-previous-word-start` — declared as data in
cdin-x's `vimode/motions.lua` and dispatched through the same registry as
everything else. They are all in [the command reference](commands.md#document).

That is the whole mechanism, and it has a consequence worth stating: **a keymap
in your `init.lua` is enough to re-bind any of them.** Vim mode does not own the
movement commands; it owns the keys that reach them.

```lua
-- ~/.config/cdin/user/init.lua
local keymap = require "core.input.keymap"
keymap.add { ["ctrl+u"] = "doc:move-to-previous-page" }
```

Which also means the honest limit: **a keymap can only reach what the runtime
already has.** There is no "move down half a page" command, so there is no way to
bind one. cdin-x documents the same limit from the other side — vim mode has no
<kbd>Ctrl</kbd>+<kbd>U</kbd> because the underlying command moves a line, and
adding one would mean a runtime command that only vim mode wants.

**The status pill is a seam, not a drawing.** Vim mode registers
`core.register_status_pill("vim_mode", fn)` and the status bar draws it. Core
never mentions vim, never names a mode, and never hardcodes a colour for it —
which is what lets the pill exist without the runtime knowing what a mode is.

**The colours are the theme's, and the runtime has no fallback for them.**
`vim_pill_fg`, `vim_normal_bg`, `vim_insert_bg`, `vim_visual_bg`,
`vim_replace_bg` and `vim_command_bg` are read from `style`, and
[`data/core/style.lua`](../../data/core/style.lua) defines fallbacks for every
other colour **except these six**. They are cdin-x's vocabulary, not the
runtime's, so they live in cdin-x's themes and not in the core defaults list.

If you write a theme by hand and the mode pill is invisible, that is why. See
[themes](themes.md#vim-mode).

**Key resolution is where integrations get their turn.** Vim mode wraps
`keymap.on_key_pressed`, and the lookup order is: vim's own keys first, and only
if they decline is the registry asked. That ordering is what makes it safe for an
integration to claim <kbd>m</kbd> or <kbd>M</kbd> — it can add a key, but it
cannot shadow one vim already handles.

If a key you expected from an integration does nothing, that is the reason, and
it is a documented property rather than a bug. The key needs vim to decline
first.

**`config.vim_mode_enabled` is not in this repository's config.** It is defined
by the vim plugin itself, with its own default, applied in its `init()` under a
`nil` guard.

```lua
-- ~/.config/cdin/user/init.lua
config.vim_mode_enabled = true    -- the default, stated explicitly
config.vim_mode_enabled = false   -- normal typing
```

A copy of that default in `data/core/config.lua` would be a key that outlives the
plugin: meaningless if the plugin were ever disabled, and one more place for the
two to disagree. The same applies to `config.session_restore` and the
`session_restore_*` keys — see
[configuration](configuration.md#owned-by-plugins-not-here) for the full list.

**A key declared in a plugin's manifest is a declaration, not an application.**
Nothing copies it onto `config`. If you want vim mode on at startup, say so.

## Turning it off

<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>V</kbd>, or `vim:toggle-mode` from any command
runner.

**The choice is not remembered across restarts** — there is no persisted state
for it. So set `config.vim_mode_enabled` if you want it stable. Every
<kbd>Ctrl</kbd>-based binding keeps working either way, since the keys vim mode
uses are its own.

## What this runtime deliberately does not know

Tabs, the file tree, search, git, splits, the extension manager, the menu.

That is not an omission and it is the design decision the whole arrangement rests
on. If vim mode had its own `:tabnew`, then removing the tab plugin would leave a
`:tabnew` that quietly did nothing — and you would have no way to tell that from
a broken one. So vim mode offers **seams** and the wiring lives in
`X/integration/vim/`, where it can be removed as a unit.

Nothing in `data/core/` names a tab, a tree, a search or a git command. When you
are reading vim mode's source and find it conspicuously thin, that is the point.

## Files

| file | holds |
| --- | --- |
| [`data/core/input/keymap.lua`](../../data/core/input/keymap.lua) | the key resolution vim mode wraps |
| [`data/core/views/statusview.lua`](../../data/core/views/statusview.lua) | the pill registry, and the branch display |
| [`data/core/style.lua`](../../data/core/style.lua) | the fallbacks — and the six it does not have |
| `X/core/vim/` | the plugin, in cdin-x |
| `X/integration/vim/` | the seven integrations that fill the seams |
