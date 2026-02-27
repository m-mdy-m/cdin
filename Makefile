MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

include mk/platform.mk
include mk/version.mk
include mk/config.mk
include mk/build.mk
include mk/install.mk

.DEFAULT_GOAL := build