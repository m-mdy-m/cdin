BIN_NAME  := cdin$(EXE_SUFFIX)
BUILD_DIR := build/$(PLATFORM)-$(BUILD)
OUT       := $(BUILD_DIR)/$(BIN_NAME)

_ALL_SRCS := $(shell find src -name '*.c' 2>/dev/null | sort)
EXCLUDE_DIRS := src/lib/lua52

_EXCLUDE_PATTERN := $(foreach d,$(EXCLUDE_DIRS),$(d)/%)

SRCS := $(filter-out $(_EXCLUDE_PATTERN),$(_ALL_SRCS))

ifeq ($(SRCS),)
  $(error No .c files found under src/. Are you in the project root?)
endif
OBJS := $(SRCS:%=$(BUILD_DIR)/%.o)
ifeq ($(PLATFORM),windows)
  RES_SRC := res.rc
  RES_OBJ := $(BUILD_DIR)/res.res
  ifeq ($(wildcard $(RES_SRC)),$(RES_SRC))
    OBJS        += $(RES_OBJ)
    HAS_RESOURCE := 1
  endif
endif
DEPS := $(OBJS:.o=.d)

export SRCS OBJS OUT BUILD_DIR BIN_NAME DEPS