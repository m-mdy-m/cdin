ifeq ($(OS),Windows_NT)
  _RAW_OS := Windows_NT
else
  _RAW_OS := $(shell uname -s 2>/dev/null || echo unknown)
endif
ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(_RAW_OS)))
  PLATFORM := windows
else ifeq ($(_RAW_OS),Linux)
  PLATFORM := linux
else ifeq ($(_RAW_OS),Darwin)
  PLATFORM := macos
else ifeq ($(_RAW_OS),Windows_NT)
  PLATFORM := windows
else
  PLATFORM := unknown
endif
ifeq ($(PLATFORM),windows)
  CC        ?= gcc
  WINDRES   ?= windres
  EXE_SUFFIX   := .exe
  SHARED_SUFFIX := .dll
else ifeq ($(PLATFORM),macos)
  CC           ?= clang
  EXE_SUFFIX   :=
  SHARED_SUFFIX := .dylib
else
  CC           ?= gcc
  EXE_SUFFIX   :=
  SHARED_SUFFIX := .so
endif
CCACHE := $(shell command -v ccache 2>/dev/null)
ifneq ($(CCACHE),)
  CC := ccache $(CC)
endif
export PLATFORM CC WINDRES EXE_SUFFIX SHARED_SUFFIX