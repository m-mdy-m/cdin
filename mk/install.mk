_INSTALL_BIN  := $(DESTDIR)$(BINDIR)/cdin
_INSTALL_DATA := $(DESTDIR)$(DATADIR)
install: build
ifeq ($(PLATFORM),windows)
	$(error 'install' is not supported on Windows. \
	  Copy $(OUT) and data/ manually.)
else
	$(call log_step,BIN,$(_INSTALL_BIN))
	@install -Dm755 $(OUT) $(_INSTALL_BIN)
	@if [ -d data ]; then \
	  printf '  %-4s  %s\n' 'DATA' '$(_INSTALL_DATA)'; \
	  install -dm755 $(_INSTALL_DATA); \
	  cp -r data/. $(_INSTALL_DATA)/; \
	fi
	$(call log_ok,Installed cdin $(VERSION) → $(DESTDIR)$(PREFIX))
endif
uninstall:
ifeq ($(PLATFORM),windows)
	$(error 'uninstall' is not supported on Windows.)
else
	$(call log_step,RM,$(_INSTALL_BIN))
	@rm -f $(_INSTALL_BIN)
	$(call log_step,RM,$(_INSTALL_DATA))
	@rm -rf $(_INSTALL_DATA)
	$(call log_ok,Uninstalled cdin from $(DESTDIR)$(PREFIX))
endif