PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib/cdin
DATADIR := $(LIBDIR)/data

BUILD ?= release
SDL_VERSION ?= auto
LUA_VERSION ?= auto
PKG_CONFIG := $(shell command -v pkg-config 2>/dev/null)

ifeq ($(BUILD),debug)
  OPT := -O0 -g3 -DDEBUG
  STRIP :=
else
  OPT := -O3 -DNDEBUG
  STRIP := -s
endif

# SDL selection: explicit value wins, otherwise prefer SDL3 then SDL2
ifeq ($(SDL_VERSION),auto)
  ifneq ($(PKG_CONFIG),)
    ifeq ($(shell $(PKG_CONFIG) --exists sdl3 && echo y),y)
      SDL_VERSION := 3
    else ifeq ($(shell $(PKG_CONFIG) --exists sdl2 && echo y),y)
      SDL_VERSION := 2
    else
      SDL_VERSION := 3
    endif
  else
    SDL_VERSION := 3
  endif
endif

SDL_PKG := sdl2
SDL_HEADER := SDL2/SDL.h
ifeq ($(SDL_VERSION),3)
  SDL_PKG := sdl3
  SDL_HEADER := SDL3/SDL.h
endif

ifneq ($(PKG_CONFIG),)
  SDL_CFLAGS := $(shell $(PKG_CONFIG) --cflags $(SDL_PKG) 2>/dev/null)
  SDL_LDFLAGS := $(shell $(PKG_CONFIG) --libs $(SDL_PKG) 2>/dev/null)
endif

ifeq ($(SDL_LDFLAGS),)
  ifeq ($(SDL_VERSION),3)
    SDL_LDFLAGS := -lSDL3
  else
    SDL_LDFLAGS := -lSDL2
  endif
endif

LUA_PKG :=
ifneq ($(PKG_CONFIG),)
  ifeq ($(LUA_VERSION),auto)
    LUA_PKG := $(firstword $(foreach p,lua5.4 lua54 lua5.3 lua53 lua,$(if $(shell $(PKG_CONFIG) --exists $(p) 2>/dev/null && echo y),$(p))))
  else
    LUA_PKG := lua$(LUA_VERSION)
  endif
endif

ifneq ($(LUA_PKG),)
  LUA_CFLAGS := $(shell $(PKG_CONFIG) --cflags $(LUA_PKG) 2>/dev/null)
  LUA_LDFLAGS := $(shell $(PKG_CONFIG) --libs $(LUA_PKG) 2>/dev/null)
  LUA_FOUND_VERSION := $(shell $(PKG_CONFIG) --modversion $(LUA_PKG) 2>/dev/null)
else
  LUA_LDFLAGS := -llua -lm -ldl
  LUA_FOUND_VERSION := unknown
endif

BASE_CFLAGS := -std=gnu11 -fno-strict-aliasing -Wall -Wextra -Wno-unused-parameter $(OPT) $(VERSION_CFLAGS) -Isrc
CFLAGS := $(BASE_CFLAGS) $(SDL_CFLAGS) $(LUA_CFLAGS)
LDFLAGS := $(SDL_LDFLAGS) $(LUA_LDFLAGS) -lm $(STRIP)

OUT_DIR := build/$(PLATFORM)-$(BUILD)
OUT := $(OUT_DIR)/cdin$(EXE)
SRCS := $(shell find src -name '*.c' | sort)
OBJS := $(SRCS:%.c=$(OUT_DIR)/%.o)
DEPS := $(OBJS:.o=.d)