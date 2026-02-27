PREFIX  ?= /usr/local
BINDIR  := $(PREFIX)/bin
DATADIR := $(PREFIX)/share/cdin

PKG_CONFIG := $(shell command -v pkg-config 2>/dev/null)
SDL_VERSION ?= 2
ifeq ($(SDL_VERSION),3)
  SDL_PKG   := sdl3
  SDL_DNAME := SDL3
else
  SDL_PKG   := sdl2
  SDL_DNAME := SDL2
endif

ifeq ($(PKG_CONFIG),)
  $(warning pkg-config not found — falling back to manual SDL flags)
  ifeq ($(PLATFORM),windows)
    SDL_CFLAGS  :=
    SDL_LDFLAGS := -lmingw32 -l$(SDL_DNAME)main -l$(SDL_DNAME)
  else
    SDL_CFLAGS  := -I/usr/local/include/$(SDL_DNAME)
    SDL_LDFLAGS := -L/usr/local/lib -l$(SDL_DNAME)
  endif
else
  SDL_CFLAGS  := $(shell $(PKG_CONFIG) --cflags $(SDL_PKG) 2>/dev/null)
  SDL_LDFLAGS := $(shell $(PKG_CONFIG) --libs   $(SDL_PKG) 2>/dev/null)
  ifeq ($(SDL_CFLAGS),)
    $(error SDL$(SDL_VERSION) not found. \
      Debian/Ubuntu: sudo apt install libsdl$(SDL_VERSION)-dev \
      MSYS2: pacman -S mingw-w64-ucrt-x86_64-sdl$(SDL_VERSION))
  endif
endif
LUA_VERSION ?= auto

ifeq ($(LUA_VERSION),auto)
  _LUA_CANDIDATES := lua5.4 lua54 lua5.3 lua53 lua5.2 lua52 lua
else
  _LUA_VER_NODOT  := $(subst .,,$(LUA_VERSION))
  _LUA_CANDIDATES := lua$(LUA_VERSION) lua$(_LUA_VER_NODOT) lua
endif

ifeq ($(PKG_CONFIG),)
  _LUA_PKG :=
else
  _LUA_PKG := $(firstword \
    $(foreach p,$(_LUA_CANDIDATES),\
      $(if $(shell $(PKG_CONFIG) --exists $(p) 2>/dev/null && echo y),$(p),)))
endif

ifeq ($(LUA_CFLAGS)$(LUA_LDFLAGS),)
  ifneq ($(_LUA_PKG),)
    LUA_CFLAGS        := $(shell $(PKG_CONFIG) --cflags $(_LUA_PKG))
    LUA_LDFLAGS       := $(shell $(PKG_CONFIG) --libs   $(_LUA_PKG))
    LUA_FOUND_VERSION := $(shell $(PKG_CONFIG) --modversion $(_LUA_PKG) 2>/dev/null)
  else
    ifeq ($(PLATFORM),windows)
      LUA_CFLAGS  :=
      LUA_LDFLAGS := -llua
    else
      LUA_CFLAGS  :=
      LUA_LDFLAGS := -llua -lm -ldl
    endif
    LUA_FOUND_VERSION := unknown
    $(warning Lua not found via pkg-config — using bare -llua)
    $(warning Debian/Ubuntu : sudo apt install liblua5.4-dev)
    $(warning Arch/Manjaro  : sudo pacman -S lua)
    $(warning MSYS2         : pacman -S mingw-w64-ucrt-x86_64-lua)
    $(warning Fedora/RHEL   : sudo dnf install lua-devel)
  endif
else
  LUA_FOUND_VERSION := custom
endif

ifneq ($(filter-out unknown custom,$(LUA_FOUND_VERSION)),)
  _LUA_MAJOR := $(word 1,$(subst ., ,$(LUA_FOUND_VERSION)))
  _LUA_MINOR := $(word 2,$(subst ., ,$(LUA_FOUND_VERSION)))
  LUA_CFLAGS += -DLUA_VERSION_MAJOR=$(_LUA_MAJOR) \
                -DLUA_VERSION_MINOR=$(_LUA_MINOR)
endif
BUILD ?= release

ifeq ($(BUILD),debug)
  OPT_FLAGS := -O0 -g3 -DDEBUG
  ifeq ($(SANITIZE),1)
    OPT_FLAGS += -fsanitize=address,undefined -fno-omit-frame-pointer
    LDFLAGS   += -fsanitize=address,undefined
  endif
else
  OPT_FLAGS  := -O3 -DNDEBUG
  STRIP_FLAG := -s
endif

BASE_CFLAGS := \
  -std=gnu11 \
  -fno-strict-aliasing \
  -Wall \
  -Wextra \
  -Wno-unused-parameter \
  $(OPT_FLAGS) \
  $(VERSION_CFLAGS) \
  -Isrc
ifeq ($(PLATFORM),windows)
  PLAT_CFLAGS  :=
  PLAT_LDFLAGS := -mwindows
else ifeq ($(PLATFORM),macos)
  PLAT_CFLAGS  :=
  PLAT_LDFLAGS :=
else
  PLAT_CFLAGS  :=
  PLAT_LDFLAGS := -lm
endif
CFLAGS  := $(BASE_CFLAGS) $(SDL_CFLAGS) $(LUA_CFLAGS) $(PLAT_CFLAGS)
LDFLAGS := $(SDL_LDFLAGS) $(LUA_LDFLAGS) $(PLAT_LDFLAGS) $(STRIP_FLAG)

export PREFIX BINDIR DATADIR
export SDL_VERSION SDL_PKG SDL_CFLAGS SDL_LDFLAGS
export LUA_VERSION LUA_FOUND_VERSION LUA_CFLAGS LUA_LDFLAGS
export BUILD OPT_FLAGS CFLAGS LDFLAGS