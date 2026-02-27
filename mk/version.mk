GIT      := $(shell command -v git 2>/dev/null)

ifeq ($(GIT),)
  VERSION  ?= 0.0.0-unknown
  COMMIT   := unknown
  DIRTY    :=
else
  _DESCRIBE := $(shell git describe --tags --always --dirty 2>/dev/null)
  ifeq ($(_DESCRIBE),)
    VERSION ?= 0.0.0-unknown
    COMMIT  := unknown
    DIRTY   :=
  else
    VERSION  ?= $(patsubst v%,%,$(_DESCRIBE))
    COMMIT   := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
    DIRTY    := $(shell git status --short 2>/dev/null | head -c1)
  endif
endif

VERSION_CFLAGS := \
  -DCDIN_VERSION=\"$(VERSION)\" \
  -DCDIN_COMMIT=\"$(COMMIT)\"

export VERSION COMMIT DIRTY VERSION_CFLAGS