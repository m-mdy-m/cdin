# Building from source

## What you need

- a C11 compiler — gcc or clang
- GNU make
- **SDL3** development headers and library
- **Lua 5.4** development headers
- `python3` — standard library for assembly, but icon generation also needs
  `Pillow` and either `cairosvg` or `rsvg-convert`
- a [cdin-x](https://github.com/m-mdy-m/cdin-x) checkout, for anything but `make bin`

```sh
# Debian / Ubuntu
sudo apt install build-essential make libsdl3-dev liblua5.4-dev python3
pip install Pillow cairosvg

# Arch
sudo pacman -S base-devel sdl3 lua python librsvg
```

**SDL3 is required, not optional.** `mk/config.mk` still carries an SDL2
auto-detect path and will link `-lSDL2` if that is all it finds, but `main.c`,
`renderer.h` and `utils.c` all `#include <SDL3/SDL.h>` unconditionally, and the
dependency check in `mk/build.mk` compiles a probe against `SDL3/SDL.h` and stops
if it is missing. So an SDL2-only machine selects SDL2 and then fails to compile.
`make info` prints `SDL  3 (required)` — a literal, not a version, which is why
it never disagrees.

Install SDL3 rather than fighting the makefile. The auto-detect is vestigial and
`SDL_VERSION=2` is not a supported configuration.

**Windows** has no package manager for this. You need MinGW, the SDL3 MinGW devel
package, and Lua 5.4 headers, and the makefile finds both through `pkg-config` —
so the mechanism is a `.pc` file on `PKG_CONFIG_PATH`, which is what the release
workflow does. Put `SDL3.dll` next to the binary afterwards.

There are **no `SDL3_PREFIX` or `LUA_PREFIX` make variables.** `SDL3_PREFIX`
appears in `make help` and in one error message, `LUA_PREFIX` appears nowhere, and
setting either does nothing.

## The quick version

```sh
git clone https://github.com/m-mdy-m/cdin-x   # next to cdin, or anywhere
git clone https://github.com/m-mdy-m/cdin
cd cdin

make                        # binary + the bundled data/ → build/<platform>-release/
make run                    # …and launch it
```

**A fresh clone does not build with `make` alone.** It needs a cdin-x checkout,
because the mandatory set — vim mode, the default theme, the fonts — lives there
and a cdin without them is not an editor. The failure message says so and names
the variable.

That split is the point, not an inconvenience. The cost is one line in a build
script; what it buys is that "the editor is broken" and "an extension misbehaves"
stop being the same investigation.

```sh
make CDINX_DIR=/path/to/cdin-x    # …using that checkout instead of ../cdin-x
```

## Targets

| target | does |
| --- | --- |
| `make` | `bin` then `bundle`. A runnable editor |
| `make bin` | **the binary only.** No cdin-x, no `data/` assembly |
| `make bundle` | assemble `build/…/data` only |
| `make run` | build, then launch |
| `make debug` | `-O0 -g3` into `build/<platform>-debug/` |
| `make info` | what was detected, and where it will go. **Run this first when something is wrong** |
| `make install` / `make uninstall` | install under `PREFIX` |
| `make clean` | remove this build's output |
| `make distclean` | remove `build/` entirely, and the generated icon header |
| `make tiny` | an `-Os` + `--gc-sections` build |
| `make gen-icons` | regenerate the icon assets |
| `make test-plugins` / `test-lua` / `test-workflows` / `test-site-dir` | the test suites, below |

Variables: `CDINX_DIR`, `PREFIX`, `DESTDIR`, `BUILD=release|debug|tiny`, `CC`,
`PYTHON`, `SDL_VERSION`, `LUA_VERSION`, `LUA`, `PLATFORM`.

**Start with `make info`.** It prints the platform, the compiler, the detected
Lua version, every flag and the output path, which is most of what a build
problem turns out to need.

### Targets that do not work

Four targets are advertised and broken. They are recorded as known issues in
`CHANGELOG.md`, and none is on a path you need:

| target | what happens |
| --- | --- |
| `make check` | runs `python scripts/check.py` — the file does not exist |
| `make size` | runs `python scripts/bench.py` — the file does not exist |
| `make test` | `.PHONY` with no rule |
| `make bench` | `.PHONY` with no rule |
| `make debug-san` | sets `SANITIZE=1`, which no makefile reads — identical to `make debug` |

**There is no lint or style checker in this repository.** The only automated check
on C is the compiler's, at `-Wall -Wextra` without `-Werror`; note that
`-Wno-unused-parameter` is also on, so a clean build means "no warning other than
unused parameters". `make help` additionally still claims that plugins and themes
ship inside `data/`, which has been untrue since 0.2.0-alpha.2.

## What `make` actually produces

`build/<platform>-<build>/cdin` — `cdin.exe` on Windows — and next to it a
`data/` directory. **The two travel together**; the binary looks for `data/`
relative to itself, so moving one without the other gives you an editor with no
fonts and no vim mode.

```
build/linux-release/
├── cdin
└── data/
    ├── core/        a link to this checkout's data/core — not a copy
    ├── plugins/     the mandatory set
    ├── themes/      default/
    ├── fonts/
    ├── X/           the extension catalog
    └── BUNDLE.lua
```

`data/core` is a **symlink to the source tree**, recreated on every build, with a
copy as a fallback on filesystems that cannot do it. That is why editing
`data/core/*.lua` needs no recompile — edit, restart, done. Only C changes
require a rebuild.

The recreate is deliberate rather than create-if-missing. A link made once and
then assumed correct is exactly how a stale copy becomes the editor you are
running, and you spend an afternoon on a bug that was fixed three commits ago.

**Only `src/` changes need `make`.** A Lua change under `data/core/` needs a
restart.

## Assembling the data

`scripts/assemble_data.py` owns it, and it does two things:

1. **Recreate `data/core`** as a symlink to the source `data/core`, falling back
   to a copy. An old `build/…/data` that is itself a symlink is unlinked, never
   followed — following one is how a build writes into your source tree.
2. **Run cdin-x's bundler**, `<CDINX_DIR>/scripts/bundle.py --out <build>/data`,
   in the same interpreter.

Everything else in `data/` comes from cdin-x's `scripts/bundle.py`: the vim
plugin, the default theme, the fonts, a one-line shim per bundled plugin, and a
`BUNDLE.lua` index. That script is cdin-x's, and its own contract is documented
in [its README](https://github.com/m-mdy-m/cdin-x/blob/main/scripts/README.md) —
but the four ways it refuses to continue are worth knowing here, because they are
the failure modes of *this* build:

- no essential plugin under `X/core/`
- not exactly one essential theme — a build has to know which one to start with,
  so zero and two are both unanswerable
- a missing or empty `fonts/`
- an output directory that is a symlink or junction, which it refuses rather than
  writing through, because a junction does not report itself as one through the
  obvious API and a check written for POSIX passes right over it

It is also idempotent: a second run over the first run's output is byte-identical
and no timestamps are preserved, so a bundle that differs between builds of the
same commit is a bug rather than a matter of trust.

**Nothing is ever fetched.** A build takes a directory and reads files out of it.

## Tests

Four suites, and they are not interchangeable. Three need only `lua` — no build,
no editor, no cdin-x.

```sh
make test-plugins     # keymap integrity and the loader
make test-lua         # unit + integration, in tests/lua/
make test-workflows   # the cdin-x workflows — needs CDINX_DIR
make test-site-dir    # the one duplicated constant, vs cdin-x
```

| suite | asserts |
| --- | --- |
| `test-plugins` | every command a binding names actually exists, **with zero plugins installed**; the palette gets a working submit and suggest; `ctrl+n` maps correctly and the seven commands the runtime moved away from are absent; `ctrl+p` / `ctrl+shift+p` / `ctrl+o` are unbound; `command.perform` on an unknown name does not raise. Then the loader and theme registry over `scripts/fixtures/`, across site-present × site-absent × `config.plugins` = `nil` / `false` / whitelist |
| `test-lua` | the text pipeline (UTF-8, bidi, shaper), `Doc` editing, and the theme registry — including that a failed `apply` leaves `style` completely untouched; and the keystroke rule, that every stroke the runtime binds is one `keymap.canonical_stroke` says a key press can produce |
| `test-workflows` | cdin-x's workflow plugins register their commands; `ctrl+p`, `ctrl+shift+p`, `ctrl+o` and `ctrl+shift+o` **each have exactly one command bound**; the **source text** of `data/core/keymaps/default.lua` names none of them; every registered predicate is callable; all seven workflow commands survive `enter → suggest → submit`; unloading `palette`, `finder` and `modules` detaches commands *and* strokes |
| `test-site-dir` | cdin's `config.site_dirname` and cdin-x's copy of it are the same string, and cdin-x reads `config.site_path()` rather than hardcoding a path |

`test-plugins` and `test-lua` build their tree from `scripts/fixtures/` rather
than from whatever happens to be on disk, so those tests can never be satisfied by
accident. `test-workflows` does the opposite on purpose: it points
`config.site_dir` straight at your `CDINX_DIR`, because the thing it is checking —
that cdin and cdin-x agree — is only meaningful against the real catalog. It also
reads `default.lua` **from disk** rather than from the loaded table, so a
plugin's `keymap.add` prepend cannot hide a stale line in the file.

**`test-workflows` is the one that cannot be replaced.** A stale runtime binding
and a duplicated plugin binding are the two failures worth catching, and neither
is visible from one repository alone — one needs cdin-x present to know what it
should have bound. Run it whenever you touch `data/core/keymaps/`, the loader, or
anything a plugin might also be registering.

`make check` is separate: it is lint and style, not tests.

## CI

Release workflows check out **this repository and cdin-x as siblings**, generate
icons, and run `make build`. The `Dockerfile` does the same. What they package is
the **assembled** `build/…/data`, never the source `data/`.

Platforms: Linux x86-64, Windows x86-64, macOS arm64 (a DMG). `release.yml`
collects the artifacts and publishes them, and separately runs the Docker matrix
— `linux/amd64` and `linux/arm64` natively, no QEMU. `docker.yml` is the
single-platform path and `deploy-website.yml` is unrelated.

## What to do before opening a pull request

```sh
make            # and make debug — both must build clean, -Wall -Wextra
make test-plugins
make test-lua
make test-workflows
```

Note there is no `make check` in that list, because it does not work.

Then run the editor and exercise what you changed.

Lua changes under `data/core/` need no recompile; only C does. So the loop is
`make` once, then edit and restart as many times as you like.

[CONTRIBUTING.md](../../CONTRIBUTING.md) has the conventions and the PR checklist.
[Troubleshooting](troubleshooting.md) has what a specific failure means.
