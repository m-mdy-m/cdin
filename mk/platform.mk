ifeq ($(OS),Windows_NT)
  PLATFORM := windows
else
  UNAME_S := $(shell uname -s 2>/dev/null)
  ifeq ($(UNAME_S),Linux)
    PLATFORM := linux
  else ifeq ($(UNAME_S),Darwin)
    PLATFORM := macos
  else ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
    PLATFORM := windows
  else
    PLATFORM := unknown
  endif
endif

CC ?= gcc
ifeq ($(PLATFORM),macos)
  CC ?= clang
endif

WINDRES ?= windres
EXE :=
ifeq ($(PLATFORM),windows)
  EXE := .exe
endif
