# =============================================================================
# config.mk — compiler flags, SDL detection, install prefix
# =============================================================================
PREFIX   ?= /usr/local
BINDIR   := $(PREFIX)/bin
DATADIR  := $(PREFIX)/share/cdin
SDL_VERSION ?= 2

ifeq ($(SDL_VERSION),3)
  SDL_PKG   := sdl3
  SDL_DNAME := SDL3
else
  SDL_PKG   := sdl2
  SDL_DNAME := SDL2
endif
PKG_CONFIG := $(shell command -v pkg-config 2>/dev/null)

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
    $(error SDL$(SDL_VERSION) not found via pkg-config. \
      Install it or set SDL_CFLAGS / SDL_LDFLAGS manually.)
  endif
endif
BUILD ?= release

ifeq ($(BUILD),debug)
  OPT_FLAGS := -O0 -g3 -DDEBUG
  ifeq ($(SANITIZE),1)
    OPT_FLAGS += -fsanitize=address,undefined -fno-omit-frame-pointer
    LDFLAGS   += -fsanitize=address,undefined
  endif
else
  OPT_FLAGS := -O3 -DNDEBUG
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
  PLAT_CFLAGS  := -DLUA_USE_POPEN
  PLAT_LDFLAGS := -mwindows
else ifeq ($(PLATFORM),macos)
  PLAT_CFLAGS  := -DLUA_USE_POSIX
  PLAT_LDFLAGS :=
else
  PLAT_CFLAGS  := -DLUA_USE_POSIX
  PLAT_LDFLAGS := -lm
endif
CFLAGS  := $(BASE_CFLAGS)  $(SDL_CFLAGS)  $(PLAT_CFLAGS)
LDFLAGS := $(SDL_LDFLAGS)  $(PLAT_LDFLAGS) $(STRIP_FLAG)

export PREFIX BINDIR DATADIR
export SDL_VERSION SDL_PKG SDL_CFLAGS SDL_LDFLAGS
export BUILD OPT_FLAGS CFLAGS LDFLAGS