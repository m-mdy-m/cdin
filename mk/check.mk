define _require_hdr
	@echo '\#include <$(1)>' \
	  | $(CC) $(CFLAGS) -x c -fsyntax-only - 2>/dev/null \
	|| { \
	  printf '\n  \033[31m✗\033[0m  $(1) not found.\n'; \
	  if [ '$(PLATFORM)' = 'windows' ]; then \
	    printf '     MSYS2  : pacman -S mingw-w64-ucrt-x86_64-$(2)\n'; \
	  else \
	    printf '     apt    : sudo apt install $(3)\n'; \
	    printf '     pacman : sudo pacman -S $(2)\n'; \
	    printf '     dnf    : sudo dnf install $(3)\n'; \
	    printf '     brew   : brew install $(2)\n'; \
	  fi; \
	  printf '\n'; \
	  exit 1; \
	}
endef
_check_deps:
	@# ── compiler ──────────────────────────────────────────────────────────
	@_cc_bin=$$(echo $(CC) | awk '{print $$NF}'); \
	if ! command -v "$$_cc_bin" >/dev/null 2>&1; then \
	  printf '\n  \033[31m✗\033[0m  compiler "%s" not found.\n' "$$_cc_bin"; \
	  printf '     Linux : sudo apt install gcc  (or pacman -S gcc)\n'; \
	  printf '     MSYS2 : pacman -S mingw-w64-ucrt-x86_64-gcc\n\n'; \
	  exit 1; \
	fi

	@# ── SDL ───────────────────────────────────────────────────────────────
	$(call _require_hdr,\
	  SDL$(SDL_VERSION)/SDL.h,\
	  sdl$(SDL_VERSION),\
	  libsdl$(SDL_VERSION)-dev,\
	  sdl$(SDL_VERSION))

	@# ── Lua ───────────────────────────────────────────────────────────────
	$(call _require_hdr,\
	  lua.h,\
	  lua,\
	  liblua5.4-dev,\
	  lua)