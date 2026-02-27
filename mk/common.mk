.PHONY: \
  build debug debug-san \
  run run-debug _run_bin \
  install uninstall \
  _check_deps \
  clean distclean \
  info help

ifeq ($(NO_COLOR),)
  ifneq ($(TERM),dumb)
    _C_RESET  := \033[0m
    _C_BOLD   := \033[1m
    _C_GREEN  := \033[32m
    _C_CYAN   := \033[36m
    _C_YELLOW := \033[33m
    _C_RED    := \033[31m
    _C_GREY   := \033[90m
  endif
endif

_LOG_W := 4   # label column width

log_step = @printf '  $(_C_CYAN)%-$(_LOG_W)s$(_C_RESET)  %s\n' '$(1)' '$(2)'
log_ok   = @printf '\n  $(_C_GREEN)✓$(_C_RESET)  %s\n\n' '$(1)'
log_warn = @printf '  $(_C_YELLOW)⚠$(_C_RESET)  %s\n' '$(1)'
log_err  = @printf '\n  $(_C_RED)✗$(_C_RESET)  %s\n\n' '$(1)'
log_sep  = @printf '  %s\n' \
             '─────────────────────────────────────────────'
define require_header
  @echo '\#include <$(1)>' \
    | $(CC) $(CFLAGS) -x c -fsyntax-only - 2>/dev/null \
  || { $(call log_err,$(2)); echo '$(3)'; echo ''; exit 1; }
endef
_info_row = @printf '  $(_C_CYAN)%-14s$(_C_RESET) %s\n' '$(1)' '$(2)'