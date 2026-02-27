info:
	@echo ''
	@printf '  $(_C_BOLD)cdin build configuration$(_C_RESET)\n'
	$(log_sep)
	$(call _info_row,VERSION,     $(VERSION))
	$(call _info_row,COMMIT,      $(COMMIT)$(if $(DIRTY), (dirty),))
	$(call _info_row,PLATFORM,    $(PLATFORM))
	$(call _info_row,BUILD,       $(BUILD))
	$(call _info_row,SDL,         $(SDL_VERSION)  [pkg: $(_LUA_PKG)])
	$(call _info_row,LUA,         $(LUA_FOUND_VERSION)$(if $(LUA_BUNDLED), ⚠ bundled,)  [pkg: $(_LUA_PKG)])
	$(call _info_row,CC,          $(CC))
	$(call _info_row,OUT,         $(OUT))
	$(call _info_row,PREFIX,      $(PREFIX))
	$(call _info_row,CFLAGS,      $(CFLAGS))
	$(call _info_row,LDFLAGS,     $(LDFLAGS))
	$(call _info_row,SRCS,        $(words $(SRCS)) files)
	$(log_sep)
	@echo ''
help:
	@echo ''
	@printf '  $(_C_BOLD)cdin $(VERSION)$(_C_RESET) — available targets\n'
	@echo ''
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'build'       'Compile cdin (default)'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'debug'       'Build with debug symbols'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'debug-san'   'Debug + ASan/UBSan'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'run'         'Build then launch'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'run-debug'   'Debug build then launch'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'install'     'Install to PREFIX (Linux/macOS)'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'uninstall'   'Remove installed files'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'clean'       'Remove current build artefacts'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'distclean'   'Remove entire build/ directory'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'info'        'Show build configuration'
	@printf '  $(_C_CYAN)%-18s$(_C_RESET) %s\n' 'help'        'Show this message'
	@echo ''
	@printf '  $(_C_BOLD)Knobs$(_C_RESET) (override on command line):\n'
	@printf '    $(_C_GREY)BUILD=debug|release$(_C_RESET)    default: release\n'
	@printf '    $(_C_GREY)SDL_VERSION=2|3$(_C_RESET)        default: 2\n'
	@printf '    $(_C_GREY)LUA_VERSION=auto|5.4$(_C_RESET)  default: auto\n'
	@printf '    $(_C_GREY)PREFIX=/path$(_C_RESET)           default: /usr/local\n'
	@printf '    $(_C_GREY)SANITIZE=1$(_C_RESET)             ASan+UBSan (debug only)\n'
	@printf '    $(_C_GREY)CC=clang$(_C_RESET)               override compiler\n'
	@printf '    $(_C_GREY)NO_COLOR=1$(_C_RESET)             disable coloured output\n'
	@echo ''
	@printf '  $(_C_BOLD)Examples$(_C_RESET):\n'
	@printf '    make\n'
	@printf '    make SDL_VERSION=3 BUILD=debug\n'
	@printf '    make install PREFIX=~/.local\n'
	@printf '    make run\n'
	@echo ''