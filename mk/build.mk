.PHONY: build clean distclean info help run debug debug-san _check_deps
.PHONY: test check bench size tiny install uninstall test-plugins test-workflows test-lua test-site-dir

ICON_INL := src/icon.inl

$(ICON_INL): scripts/gen_icon.py scripts/icon.svg
	@command -v python3 >/dev/null || { echo '✗ python3 not found (needed to generate $(ICON_INL))'; exit 1; }
	python3 scripts/gen_icon.py  scripts/icon.svg --out $(ICON_INL) --out-dir scripts/icons

.PHONY: gen-icons
gen-icons: scripts/gen_icon.py scripts/icon.svg
	python3 scripts/gen_icon.py  scripts/icon.svg --no-inl --out-dir scripts/icons

# The `build` target (binary + assembled data/) lives in mk/bundle.mk, which
# is where the one build input naming an external checkout, CDINX_DIR, is
# read. This file owns compilation only; `bin` there is the compile half of
# `make`.

$(OUT): _check_deps $(OBJS)
	@mkdir -p $(dir $@)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

$(OUT_DIR)/src/core/window.o: src/core/window.c $(ICON_INL)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(OUT_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(DEPS)

_check_deps:
	@command -v $(word $(words $(CC)),$(CC)) >/dev/null || { echo 'compiler not found: $(CC)'; exit 1; }
	@printf '#include <SDL3/SDL.h>\n' | $(CC) $(CFLAGS) -x c -fsyntax-only - >/dev/null 2>&1 || { \
		echo '✗ SDL3/SDL.h not found — install libsdl3-dev or set SDL3_PREFIX=/path/to/sdl3'; \
		exit 1; }
	@printf '#include <lua.h>\n' | $(CC) $(CFLAGS) -x c -fsyntax-only - >/dev/null 2>&1 || { \
		echo '✗ lua.h not found'; \
		echo '  apt: sudo apt install liblua5.4-dev'; \
		echo '  pacman: sudo pacman -S lua'; \
		exit 1; }

run: build
	@$(OUT)

debug:
	@$(MAKE) BUILD=debug

debug-san:
	@$(MAKE) BUILD=debug SANITIZE=1

clean:
	rm -rf $(OUT_DIR)

distclean:
	rm -rf build
	rm -f $(ICON_INL)

info:
	@echo ''
	@echo 'cdin build configuration'
	@echo '────────────────────────────────────────'
	@printf '  %-12s %s\n' 'VERSION' '$(VERSION)'
	@printf '  %-12s %s\n' 'COMMIT' '$(COMMIT)'
	@printf '  %-12s %s\n' 'TREE' '$(if $(DIRTY),dirty,clean)'
	@printf '  %-12s %s\n' 'PLATFORM' '$(PLATFORM)'
	@printf '  %-12s %s\n' 'BUILD' '$(BUILD)'
	@printf '  %-12s %s\n' 'SDL' '3 (required)'
	@printf '  %-12s %s [pkg: %s]\n' 'LUA' '$(LUA_FOUND_VERSION)' '$(if $(LUA_PKG),$(LUA_PKG),manual)'
	@printf '  %-12s %s\n' 'CC' '$(CC)'
	@printf '  %-12s %s\n' 'OUT' '$(OUT)'
	@printf '  %-12s %s\n' 'ICON_INL' '$(ICON_INL)'
	@printf '  %-12s %s\n' 'PREFIX' '$(PREFIX)'
	@printf '  %-12s %s\n' 'SRCS' '$(words $(SRCS)) files'
	@printf '  %-12s %s\n' 'CFLAGS' '$(CFLAGS)'
	@printf '  %-12s %s\n' 'LDFLAGS' '$(LDFLAGS)'
	@echo '────────────────────────────────────────'
	@echo ''

help:
	@echo 'Targets: build (default), run, debug, clean, distclean, install, uninstall, info, help'
	@echo ''
	@echo 'A plain "make" is all you need — plugins and themes ship inside data/,'
	@echo 'so there is nothing to fetch, clone or install first.'
	@echo ''
	@echo 'Options: SDL3_PREFIX=/path BUILD=release|debug PREFIX=/usr/local LUA_VERSION=auto|5.4'
	@echo 'Quality: test, check, bench, size, tiny (BUILD=tiny, -Os + gc-sections)'
	@echo '          test-plugins  — keymap + loader, runtime only (needs lua)'
	@echo '          test-workflows — the cdin-x workflows and their strokes (needs lua + CDINX_DIR)'
	@echo '          test-lua      — unit + integration suite in tests/lua (needs lua)'

check:
	python scripts/check.py

# Lua data-layer tests: run with plain lua, no build, no editor, and no
# checkout of anything. Everything they exercise is built from
# scripts/fixtures/, so a test can never be satisfied by whatever happens to
# be on disk.
#
#   1. scripts/test_commands.lua  keymap integrity with 0 plugins: every
#                                 command the keymap names must exist, the
#                                 palette must hand :enter() a working submit
#                                 and suggest, and the runtime must own
#                                 exactly the bindings it is supposed to own.
#                                 This is the "ctrl+o opens a menu that does
#                                 nothing" check.
#   2. scripts/test_lua.lua       the loader and the theme registry, over
#                                 scripts/fixtures/:
#                                   - site full/empty  x config.plugins
#                                     nil / false / {demo} / {raiser}
#
# Separate processes on purpose: each run needs a fresh EXEDIR and a fresh
# config.plugins, and sharing one process makes them fight over package.loaded.
#
# Override CDIN_DIR to point the tests at a prebuilt tree instead of the
# fixture one. LUA=... to pick an interpreter.
test-plugins:
	@command -v $(LUA) >/dev/null 2>&1 || command -v lua >/dev/null 2>&1 || { \
		echo '✗ lua not found (apt: sudo apt install lua5.4)'; exit 1; }
	@echo '── keymap integrity, 0 plugins ──'
	@CDIN_SRC="$(CURDIR)" CDIN_DIR="$(TEST_CDIN_DIR)" $(LUA_RUNNER) scripts/test_commands.lua
	@for site in full empty; do \
		for sel in nil false demo raiser; do \
			case "$$sel" in \
				nil)     v='' ;; \
				false)   v=false ;; \
				*)       v=$$sel ;; \
			esac; \
			echo ''; \
			echo "── loader: site=$$site config.plugins=$$sel ──"; \
			CDIN_SRC="$(CURDIR)" CDIN_DIR="$(TEST_CDIN_DIR)" CDIN_SITE=$$site CDIN_PLUGINS="$$v" \
				$(LUA_RUNNER) scripts/test_lua.lua || exit 1; \
		done; \
	done

# The other half of the split: with a cdin-x checkout as the site directory,
# the workflow plugins must register their commands and own ctrl+p,
# ctrl+shift+p and ctrl+o — and nothing else may be bound to them.
#
# This one needs CDINX_DIR, unlike test-plugins. That is the point: it is the
# only test that reads the other repository, and it is testing the *other*
# repository's half of the contract, so there is nothing for it to do without
# a checkout to read. CDINX_DIR comes from mk/bundle.mk, the same variable the
# build uses.
#
#   site=full   cdin-x installed: the workflows are present and own the strokes
#   site=empty  nothing installed: the runtime must still own none of them
#
# The empty run is not redundant with test-plugins: it is the same assertion
# made through the real loader against a real absent site, which is the state
# a user is in before they install anything.
test-workflows:
	@command -v $(LUA) >/dev/null 2>&1 || command -v lua >/dev/null 2>&1 || { \
		echo '✗ lua not found (apt: sudo apt install lua5.4)'; exit 1; }
	@for site in full empty; do \
		echo ''; \
		echo "── workflows: site=$$site ──"; \
		CDIN_SRC="$(CURDIR)" CDINX_DIR="$(CDINX_DIR)" CDIN_SITE=$$site \
			$(LUA_RUNNER) scripts/test_workflows.lua || exit 1; \
	done

# The site directory name. Needs a cdin-x checkout, because the whole
# point of the test is that the two halves cannot disagree about where
# extensions live: cdin owns the name, cdin-x's installer copies it, and
# a mismatch would install where the loader does not look.
test-site-dir:
	@command -v $(LUA) >/dev/null 2>&1 || command -v lua >/dev/null 2>&1 || { \
		echo 'lua not found (apt: sudo apt install lua5.4)'; exit 1; }
	@test -d "$(CDINX_DIR)" || { \
		echo 'CDINX_DIR does not exist: $(CDINX_DIR)'; exit 1; }
	@echo '-- site directory name --'
	@CDIN_SRC="$(CURDIR)" CDINX_DIR="$(CDINX_DIR)" $(LUA_RUNNER) scripts/test_site_dir.lua

# The unit/integration suite in tests/lua. It predates test-plugins and covers
# what that one does not: the text pipeline, Doc, and the theme registry's
# contracts against a real fixture tree.
#
# It has no make target of its own in the tree today, so it is run by hand and
# quietly rots — which is how two of its files came to require a data/themes/
# that the split moved to cdin-x. It is wired up here so that cannot happen
# unnoticed again.
#
# The theme tests need a tree holding data/themes/<name>/theme.lua, since the
# bundled theme now lives in cdin-x. Rather than grow a second copy of the
# fixture-copying code, this asks scripts/test_lua.lua to build the tree it
# already builds and asserts against, and points these tests at the result.
# site=empty keeps it to the bundled half.
test-lua:
	@command -v $(LUA) >/dev/null 2>&1 || command -v lua >/dev/null 2>&1 || { \
		echo '✗ lua not found (apt: sudo apt install lua5.4)'; exit 1; }
	@CDIN_SRC="$(CURDIR)" CDIN_DIR="$(TEST_CDIN_DIR)" CDIN_SITE=empty CDIN_PLUGINS=false \
		$(LUA_RUNNER) scripts/test_lua.lua >/dev/null
	@echo '── unit + integration ──'
	@CDIN_THEME_TREE="$(THEME_TREE)" $(LUA_RUNNER) tests/lua/run.lua

size:
	@echo '-- binary / data sizes --'
	@python scripts/bench.py
	@echo ''
	@echo '-- largest data dirs --'
	@python -c "from pathlib import Path; r=Path('data'); ds=sorted(((sum(f.stat().st_size for f in d.rglob('*') if f.is_file()), d) for d in r.iterdir() if d.is_dir()), reverse=True); [print(f'  {d}: {s/1024:.1f} KiB') for s,d in ds]"

tiny:
	@$(MAKE) BUILD=tiny
