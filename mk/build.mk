.PHONY: build clean distclean info help run debug debug-san _check_deps _check_cdin_x cdin-x-setup cdin-x-update cdin-x-validate cdin-x-build cdin-x-clean cdin-x
.PHONY: test check bench size tiny install uninstall
.PHONY: cdin-x-fetch cdin-x-dev-setup cdin-x-dev-update

ICON_INL := src/icon.inl

$(ICON_INL): scripts/gen_icon.py scripts/icon.svg
	@command -v python3 >/dev/null || { echo '✗ python3 not found (needed to generate $(ICON_INL))'; exit 1; }
	python3 scripts/gen_icon.py  scripts/icon.svg --out $(ICON_INL) --out-dir scripts/icons

.PHONY: gen-icons
gen-icons: scripts/gen_icon.py scripts/icon.svg
	python3 scripts/gen_icon.py  scripts/icon.svg --no-inl --out-dir scripts/icons

build: _check_cdin_x $(OUT)
	@if [ -d data ] && [ ! -e $(OUT_DIR)/data ]; then \
		ln -s "$(abspath data)" $(OUT_DIR)/data; \
	fi
	@printf '\n✓ Built %s\n\n' '$(OUT)'

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

CDIN_X_REPO_SLUG ?=
CDIN_X_REF ?=
CDIN_X_RAW_BASE ?=

_check_cdin_x:
	@if [ ! -e "$(CURDIR)/data/core/x/manager.lua" ]; then \
		echo "✗ cdin-x runtime not found in data/core/x. Run: make cdin-x-setup"; \
		exit 1; \
	fi

cdin-x-setup:
	@CDIN_X_REPO_SLUG="$(CDIN_X_REPO_SLUG)" CDIN_X_REF="$(CDIN_X_REF)" CDIN_X_RAW_BASE="$(CDIN_X_RAW_BASE)" \
		sh scripts/fetch-cdin-x.sh "$(CURDIR)"

cdin-x-update: cdin-x-setup

cdin-x-clean:
	@rm -rf data/core/x data/X
	@echo "removed data/core/x and data/X — run 'make cdin-x-setup' to reinstall"

cdin-x: cdin-x-setup

# --- Contributor path: full local cdin-x checkout, symlinked in -----------
CDIN_X_DIR ?= $(shell dirname $(CURDIR))/cdin-x
CDIN_X_REPO ?= https://github.com/m-mdy-m/cdin-x.git

cdin-x-dev-setup:
	@if [ -d "$(CDIN_X_DIR)" ]; then \
		echo "cdin-x already exists at $(CDIN_X_DIR)"; \
	else \
		echo "Cloning cdin-x into $(CDIN_X_DIR)..."; \
		git clone "$(CDIN_X_REPO)" "$(CDIN_X_DIR)"; \
	fi
	@cd "$(CDIN_X_DIR)" && sh scripts/install.sh "$(CURDIR)" --symlink
	@echo "cdin-x dev checkout linked — symlinks: data/core/x -> cdin-x/core, data/X -> cdin-x/X, data/fonts -> cdin-x/fonts"

cdin-x-dev-update:
	@if [ -d "$(CDIN_X_DIR)/.git" ]; then \
		cd "$(CDIN_X_DIR)" && git pull --ff-only; \
	else \
		echo "cdin-x dev checkout not found. Run 'make cdin-x-dev-setup' first."; \
		exit 1; \
	fi
	@cd "$(CDIN_X_DIR)" && sh scripts/install.sh "$(CURDIR)" --symlink
	@echo "cdin-x dev checkout updated and re-linked."

cdin-x-validate:
	@cd "$(CDIN_X_DIR)" && lua scripts/validate.lua
	@echo "cdin-x validation passed"

cdin-x-build: cdin-x-validate
	@cd "$(CDIN_X_DIR)" && lua scripts/generate-manifest.lua
	@echo "cdin-x manifest generated"

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
	@echo '  cdin-x-setup      Fetch essential cdin-x runtime + plugins + default theme (no clone, no git needed)'
	@echo '  cdin-x-update     Same as cdin-x-setup, re-fetches the essential set'
	@echo '  cdin-x-clean      Remove data/core/x and data/X'
	@echo '  cdin-x-dev-setup  [cdin-x contributors] clone cdin-x as a sibling checkout and symlink it in'
	@echo '  cdin-x-dev-update [cdin-x contributors] git pull the sibling checkout and re-link'
	@echo '  cdin-x-validate   [cdin-x contributors] validate cdin-x structure (needs sibling checkout)'
	@echo '  cdin-x-build   Validate + generate manifest'
	@echo 'Options: SDL3_PREFIX=/path BUILD=release|debug PREFIX=/usr/local LUA_VERSION=auto|5.4'
	@echo 'Quality: test, check, bench, size, tiny (BUILD=tiny, -Os + gc-sections)'

check:
	python scripts/check.py

size:
	@echo '-- binary / data sizes --'
	@python scripts/bench.py
	@echo ''
	@echo '-- largest data dirs --'
	@python -c "from pathlib import Path; r=Path('data'); ds=sorted(((sum(f.stat().st_size for f in d.rglob('*') if f.is_file()), d) for d in r.iterdir() if d.is_dir()), reverse=True); [print(f'  {d}: {s/1024:.1f} KiB') for s,d in ds]"

tiny:
	@$(MAKE) BUILD=tiny
