# Troubleshooting

Common problems and how to fix them. If something isn't here, check `cdin.log`
(written next to the binary on each run) — most errors show up there with
enough context to figure out what went wrong.

---

## Build problems

### SDL3 not found

```
error: sdl3/SDL.h: No such file or directory
```

Install the SDL3 development package. On most distros:

```sh
# Debian / Ubuntu
sudo apt install libsdl3-dev

# Arch
sudo pacman -S sdl3

# Fedora
sudo dnf install SDL3-devel

# macOS (Homebrew)
brew install sdl3
```

If SDL3 isn't available for your distro yet, SDL2 also works. cdin
auto-detects whichever is installed (SDL3 takes priority). To force SDL2:

```sh
make SDL_VERSION=2
```

### Lua 5.4 not found

```
error: lua.h: No such file or directory
```

Install Lua 5.4 headers:

```sh
# Debian / Ubuntu
sudo apt install liblua5.4-dev

# Arch
sudo pacman -S lua54

# macOS
brew install lua
```

Some distros package the headers under a versioned path. If `pkg-config lua5.4`
returns nothing, check what's available: `pkg-config --list-all | grep lua`.
Then tell make which one to use: `make LUA_VERSION=5.4`.

### Python error during icon generation

```
ModuleNotFoundError: No module named 'cairosvg'
```

Install the Python dependencies:

```sh
pip install cairosvg Pillow
```

If you don't want to install them, the build will still work as long as
`src/icon.inl` exists in the repository — it's pre-generated and checked in.
The Python step only runs when it's missing or when you explicitly regenerate
icons.

### Warnings treated as errors

The default flags include `-Wall -Wextra` but not `-Werror`. If you're seeing
compile errors from warnings, check whether your environment or IDE added
`-Werror`. Remove it from `CFLAGS` or run:

```sh
make CFLAGS_EXTRA=""
```

---

## Startup problems

### The editor exits immediately

Run it from a terminal so you can see the output:

```sh
./build/linux-release/cdin
```

Also check `cdin.log` next to the binary. If a Lua plugin failed to load, the
error and stack trace are there.

### A plugin error at startup

cdin logs plugin errors but continues loading. You'll see something like:

```
[ERROR] plugin 'my_plugin' — attempt to index a nil value (global 'nonexistent')
```

The editor starts anyway. To diagnose: open the log view with `core:open-log`
from the command palette (`Ctrl+Shift+P`). The full error is there.

If the broken plugin is in `data/plugins/`, you can rename it to
`my_plugin.lua.disabled` to skip it without deleting it.

### The window is tiny / huge

cdin reads the display scale factor at startup and applies it to fonts and
metrics. On some HiDPI setups this detection goes wrong. You can force the
scale in `data/user/init.lua`:

```lua
-- uncomment and set to 1.0 for a normal display or 2.0 for HiDPI
-- SCALE = 1.0
```

`SCALE` is a global set by the C side before Lua starts, so reassigning it
there affects all size calculations.

---

## Editor behavior

### I'm stuck in Normal mode / can't type

cdin starts every buffer in Normal mode. Press `i` to enter Insert mode. The
`[NORMAL]` indicator in the bottom-left status bar changes to `[INSERT]`.

If you want to disable modal editing entirely:

```lua
-- data/user/init.lua
local config = require "core.config"
config.vim_mode_enabled = false
```

### Keybinding isn't working

Check the command palette (`Ctrl+Shift+P`) first — it shows every valid
command and its current binding. If the key you expect isn't listed, either
the binding isn't set or the command isn't valid in the current context
(commands have predicates; some only activate when a document is focused).

Check for conflicts: another binding might be handling the key first. In
`data/user/init.lua`, you can override any binding:

```lua
keymap.add({ ["ctrl+something"] = "the-command-you-want" }, true)
```

The `true` forces the override.

### Find (`Ctrl+F`) isn't matching what I expect

cdin's find uses Lua patterns by default, not plain strings. Characters like
`.`, `*`, `(`, `)`, `+`, `?` are pattern metacharacters. If you're searching
for a literal dot or parenthesis, escape it with `%`:

```
%.    -- matches a literal dot
%(    -- matches a literal open paren
```

To search for something that contains many special characters, use the
replace commands with the "plain" variant from the command palette.

### File shows as modified but I didn't change it

Trailing whitespace trimming runs on every save. If your file has trailing
spaces and you save it, it comes back clean and the unsaved-changes marker
goes away. If the marker is showing on a file you haven't touched:

- The file may have been changed by another process (autoreload detects this
  and offers to reload)
- A plugin may have patched `Doc.save` and introduced a spurious change

Check `cdin.log` for autoreload messages.

### Session isn't restoring

Session restore is off by default. To enable it:

```lua
config.session_restore = true
```

The session is saved automatically on quit (controlled by
`config.session_save_on_quit`, which is `true` by default). If restore isn't
working after enabling it, the session file may be missing or corrupt. Save it
manually with `session:save` from the command palette, then quit and reopen.

---

## Tree view

### Git markers (A/M/D/?) aren't showing

The tree view runs `git status --porcelain` in the background to collect
markers. A few reasons this might not work:

- The project isn't a git repository — open cdin in a directory that is one
- `git` isn't on your `PATH`
- The git poll errored — check `cdin.log`

You can disable git markers if they're causing trouble:

```lua
config.treeview_git_enabled = false
```

### The tree is slow to update

On large repositories, `git status` can be slow. Increase the polling interval:

```lua
config.treeview_git_update_rate = 10  -- seconds between polls (default: 2)
```

Or disable it entirely if you don't need the markers.

---

## Performance

### Startup feels slow

The most common cause is the git status subprocess that the tree view runs
on startup. See the tree view section above.

If startup is still slow, check `cdin.log` for timing information and for any
errors from plugins during load.

### The editor is sluggish while typing

Open the log view (`core:open-log`) and watch for error messages repeating
rapidly — a plugin in a background thread may be crashing and restarting.

Also check `config.fps`. The default is 60. Raising it won't help with typing
latency; lowering it (to 30, for example) reduces CPU use when you're not
actively editing.

### High CPU when idle

cdin's renderer uses a cell cache and only redraws changed regions. An idle
editor should draw almost nothing. If the CPU is high while idle:

- A background coroutine may be polling too aggressively — look for calls to
  `core.add_thread` in plugins with very short `coroutine.yield` intervals
- A view may be requesting redraws unnecessarily — check for `core.redraw = true`
  being set in a tight loop

---

## Crashes

### The editor crashed and I lost work

cdin saves dirty (unsaved) documents to `<filename>~` next to the original on
crash. Look for those files. A stack trace is written to `error.txt` in the
directory where the binary ran.

### Reporting a crash

Open an issue with the contents of `error.txt` and `cdin.log`, the steps that
triggered the crash, and your platform. If the crash is in the C layer, a
build with sanitizers may give more information:

```sh
make debug SANITIZE=address
./build/linux-debug/cdin
# reproduce the crash
```

---

## Ex commands

### `:w` says the file doesn't exist

`:w` saves to the current file. If the buffer has no file yet (you opened a
new untitled document), use `:w path/to/file.txt` to give it a name. Or use
`Ctrl+Shift+S` (save as).

### `:!cmd` output doesn't appear

Shell output opens in a new scratch buffer. If nothing appeared, the command
may have exited silently. The buffer is created even for empty output — look
for a tab with a name like `[shell]` or `[!ls]`. If you don't see it, check
`cdin.log` for errors from the shell plugin.

---

## Still stuck?

Open an issue on GitHub with:

- What you expected to happen
- What happened instead
- Your platform, SDL version, and Lua version (`make info` prints these)
- The contents of `cdin.log`
- Steps to reproduce

Discussions are also open for questions that aren't bug reports.