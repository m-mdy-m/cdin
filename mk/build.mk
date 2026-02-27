build: _check_deps $(OUT)
	$(call log_ok,Built $(OUT)  [SDL$(SDL_VERSION) | Lua $(LUA_FOUND_VERSION) | $(BUILD) | $(VERSION)])

$(OUT): $(OBJS)
	$(call log_step,LD,$@)
	@$(CC) $(OBJS) -o $@ $(LDFLAGS)
$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(call log_step,CC,$<)
	@$(CC) $(CFLAGS) -MMD -MP -c $< -o $@
ifeq ($(HAS_RESOURCE),1)
$(RES_OBJ): $(RES_SRC)
	@mkdir -p $(dir $@)
	$(call log_step,RC,$<)
	@$(WINDRES) $< -O coff -o $@
endif
-include $(DEPS)
debug:
	$(MAKE) BUILD=debug
debug-san:
	$(MAKE) BUILD=debug SANITIZE=1.PHONY: build clean distclean info help run debug _check_deps

build: $(OUT)
	@printf '\n✓ Built %s\n\n' '$(OUT)'

$(OUT): _check_deps $(OBJS)
	@mkdir -p $(dir $@)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

$(OUT_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(DEPS)

_check_deps:
	@command -v $(word $(words $(CC)),$(CC)) >/dev/null || { echo 'compiler not found: $(CC)'; exit 1; }
	@printf '#include <$(SDL_HEADER)>\n' | $(CC) $(CFLAGS) -x c -fsyntax-only - >/dev/null 2>&1 || { \
		echo '✗ $(SDL_HEADER) not found'; \
		echo '  apt: sudo apt install libsdl$(SDL_VERSION)-dev'; \
		echo '  pacman: sudo pacman -S sdl$(SDL_VERSION)'; \
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
	@printf '  %-12s %s [pkg: %s]\n' 'SDL' '$(SDL_VERSION)' '$(SDL_PKG)'
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
	@echo 'Options: SDL_VERSION=auto|2|3 BUILD=release|debug PREFIX=/usr/local LUA_VERSION=auto|5.4'