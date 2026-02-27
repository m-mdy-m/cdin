MAKEFLAGS += --no-builtin-rules
.SUFFIXES:
.DELETE_ON_ERROR:

include mk/platform.mk
include mk/version.mk
include mk/config.mk
include mk/sources.mk
.DEFAULT_GOAL := build
.PHONY: build debug debug-san run run-debug _run_bin install uninstall _check_deps clean distclean info help
build: _check_deps $(OUT)
	@echo ""
	@echo "  ✓  Built $(OUT)  [SDL$(SDL_VERSION) | $(BUILD) | $(VERSION)]"
	@echo ""
$(OUT): $(OBJS)
	@echo "  LD  $@"
	$(CC) $(OBJS) -o $@ $(LDFLAGS)
$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	@echo "  CC  $<"
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@
ifeq ($(HAS_RESOURCE),1)
$(RES_OBJ): $(RES_SRC)
	@mkdir -p $(dir $@)
	@echo "  RC  $<"
	$(WINDRES) $< -O coff -o $@
endif
-include $(DEPS)
debug:
	$(MAKE) BUILD=debug
debug-san:
	$(MAKE) BUILD=debug SANITIZE=1
run: build
	@echo "  RUN $(OUT)"
	@$(OUT)
run-debug: debug
	@$(MAKE) BUILD=debug _run_bin

_run_bin:
	@$(OUT)
install: build
ifeq ($(PLATFORM),windows)
	$(error install target is not supported on Windows. \
	  Copy $(OUT) and the data/ folder manually.)
else
	@echo "  INSTALL  $(BINDIR)/cdin"
	@install -Dm755 $(OUT)         $(DESTDIR)$(BINDIR)/cdin
	@if [ -d data ]; then \
	  echo "  INSTALL  $(DATADIR)"; \
	  install -dm755 $(DESTDIR)$(DATADIR); \
	  cp -r data/. $(DESTDIR)$(DATADIR)/; \
	fi
	@echo ""
	@echo "  ✓  Installed cdin $(VERSION) → $(DESTDIR)$(PREFIX)"
	@echo ""
endif
uninstall:
ifeq ($(PLATFORM),windows)
	$(error uninstall not supported on Windows.)
else
	@echo "  REMOVE  $(DESTDIR)$(BINDIR)/cdin"
	rm -f $(DESTDIR)$(BINDIR)/cdin
	@echo "  REMOVE  $(DESTDIR)$(DATADIR)"
	rm -rf $(DESTDIR)$(DATADIR)
endif
_check_deps:
	@# Verify the compiler is reachable (strips ccache prefix for the test)
	@_cc_bin=$$(echo $(CC) | awk '{print $$NF}'); \
	if ! command -v "$$_cc_bin" >/dev/null 2>&1; then \
	  echo ""; \
	  echo "  ERROR: compiler '$$_cc_bin' not found."; \
	  echo "  Linux : sudo apt install gcc  (or pacman -S gcc)"; \
	  echo "  MSYS2 : pacman -S mingw-w64-ucrt-x86_64-gcc"; \
	  echo ""; \
	  exit 1; \
	fi
	@# Verify SDL headers are accessible
	@_sdl_hdr=SDL$(SDL_VERSION)/SDL.h; \
	echo "#include <$$_sdl_hdr>" | $(CC) $(CFLAGS) -x c -fsyntax-only - 2>/dev/null || { \
	  echo ""; \
	  echo "  ERROR: SDL$(SDL_VERSION) headers not found."; \
	  if [ "$(PLATFORM)" = "windows" ]; then \
	    echo "  MSYS2 : pacman -S mingw-w64-ucrt-x86_64-sdl$(SDL_VERSION)"; \
	  else \
	    echo "  apt   : sudo apt install libsdl$(SDL_VERSION)-dev"; \
	    echo "  pacman: sudo pacman -S sdl$(SDL_VERSION)"; \
	    echo "  or build from source — see README"; \
	  fi; \
	  echo ""; \
	  exit 1; \
	}
	@# Verify Lua headers are accessible
	@echo "#include <lua.h>" | $(CC) $(CFLAGS) -x c -fsyntax-only - 2>/dev/null || { \
	  echo ""; \
	  echo "  ERROR: Lua headers not found."; \
	  echo "  Debian/Ubuntu : sudo apt install liblua5.4-dev"; \
	  echo "  Arch/Manjaro  : sudo pacman -S lua"; \
	  echo "  MSYS2         : pacman -S mingw-w64-ucrt-x86_64-lua"; \
	  echo "  Fedora/RHEL   : sudo dnf install lua-devel"; \
	  echo "  macOS         : brew install lua"; \
	  echo "  or: make LUA_CFLAGS='-I/path/to/lua' LUA_LDFLAGS='-llua'"; \
	  echo ""; \
	  exit 1; \
	}
clean:
	@echo "  CLEAN  $(BUILD_DIR)"
	rm -rf $(BUILD_DIR)
distclean:
	@echo "  DISTCLEAN  build/"
	rm -rf build/
info:
	@echo ""
	@echo "  cdin build configuration"
	@echo "  ─────────────────────────────────────────"
	@echo "  VERSION     : $(VERSION)"
	@echo "  COMMIT      : $(COMMIT)$(if $(DIRTY), (dirty),)"
	@echo "  PLATFORM    : $(PLATFORM)"
	@echo "  BUILD       : $(BUILD)"
	@echo "  SDL_VERSION : $(SDL_VERSION)"
	@echo "  LUA_FOUND   : $(_LUA_PKG)  ($(LUA_FOUND_VERSION))"
	@echo "  LUA         : $(LUA_VERSION)$(if $(LUA_BUNDLED), ⚠ bundled,)"
	@echo "  CC          : $(CC)"
	@echo "  OUT         : $(OUT)"
	@echo "  PREFIX      : $(PREFIX)"
	@echo "  CFLAGS      : $(CFLAGS)"
	@echo "  LDFLAGS     : $(LDFLAGS)"
	@echo "  SRCS        : $(words $(SRCS)) files"
	@echo "  ─────────────────────────────────────────"
	@echo ""
help:
	@echo ""
	@echo "  cdin $(VERSION) — available targets"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) \
	  | sed 's/^## //' \
	  | awk -F': ' '{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Knobs (override on command line):"
	@echo "    BUILD=debug|release   (default: release)"
	@echo "    SDL_VERSION=2|3       (default: 2)"
	@echo "    PREFIX=/path          Install prefix (default: /usr/local)"
	@echo "    SANITIZE=1            Enable ASan+UBSan (debug only)"
	@echo "    CC=clang              Override compiler"
	@echo ""
	@echo "  Examples:"
	@echo "    make                          # release build, SDL2"
	@echo "    make SDL_VERSION=3 BUILD=debug"
	@echo "    make install PREFIX=~/.local"
	@echo "    make run"
	@echo ""