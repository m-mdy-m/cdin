GIT := $(shell command -v git 2>/dev/null)

ifeq ($(GIT),)
  GIT_TAG :=
  COMMIT := unknown
  DIRTY :=
else
  GIT_TAG := $(shell $(GIT) describe --tags --abbrev=0 2>/dev/null)
  COMMIT := $(shell $(GIT) rev-parse --short HEAD 2>/dev/null || echo unknown)
  DIRTY := $(shell test -n "$$($(GIT) status --porcelain 2>/dev/null)" && echo -dirty)
endif

ifeq ($(strip $(GIT_TAG)),)
  VERSION ?= 0.0.0+$(COMMIT)$(DIRTY)
else
  VERSION ?= $(patsubst v%,%,$(GIT_TAG))$(DIRTY)
endif

VERSION_CFLAGS := -DCDIN_VERSION=\"$(VERSION)\" -DCDIN_COMMIT=\"$(COMMIT)\"