.PHONY: build clean distclean info help run debug debug-san _check_deps

# windows.c embeds the window icon from this generated header; see
# scripts/gen_icon.py. Generated automatically so a fresh checkout just
# builds — nobody should have to know this step exists.
ICON_INL := icon.inl

$(ICON_INL): scripts/gen_icon.py
	@command -v python3 >/dev/null || { echo '✗ python3 not found (needed to generate $(ICON_INL))'; exit 1; }
	python3 scripts/gen_icon.py --out $(ICON_INL)

build: $(OUT)
	@if [ -d data ] && [ ! -e $(OUT_DIR)/data ]; then \
		ln -s "$(abspath data)" $(OUT_DIR)/data; \
	fi
	@printf '\n✓ Built %s\n\n' '$(OUT)'

$(OUT): _check_deps $(OBJS)
	@mkdir -p $(dir $@)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

$(OUT_DIR)/src/core/windows.o: src/core/windows.c $(ICON_INL)
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
	@printf '  %-12s %s\n' 'PREFIX' '$(PREFIX)'
	@printf '  %-12s %s\n' 'SRCS' '$(words $(SRCS)) files'
	@printf '  %-12s %s\n' 'CFLAGS' '$(CFLAGS)'
	@printf '  %-12s %s\n' 'LDFLAGS' '$(LDFLAGS)'
	@echo '────────────────────────────────────────'
	@echo ''

help:
	@echo 'Targets: build (default), run, debug, clean, distclean, install, uninstall, info, help'
	@echo 'Options: SDL3_PREFIX=/path BUILD=release|debug PREFIX=/usr/local LUA_VERSION=auto|5.4'