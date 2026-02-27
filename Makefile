MAKEFLAGS += --no-builtin-rules
.SUFFIXES:
.DELETE_ON_ERROR:

include mk/platform.mk   # OS / compiler / toolchain
include mk/version.mk    # git-tag version string
include mk/config.mk     # SDL + Lua flags, build type, PREFIX
include mk/sources.mk    # source discovery, object list
include mk/common.mk     # .PHONY list, log helpers
include mk/check.mk      # _check_deps  (called by build automatically)
include mk/build.mk      # build / debug / debug-san + compile rules
include mk/run.mk        # run / run-debug
include mk/install.mk    # install / uninstall
include mk/clean.mk      # clean / distclean
include mk/info.mk       # info / help

# --- default goal --------------------------------------------------------
.DEFAULT_GOAL := build