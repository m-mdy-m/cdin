.PHONY: install uninstall

install: build
	@install -dm755 $(DESTDIR)$(LIBDIR)
	@install -m755 $(OUT) $(DESTDIR)$(LIBDIR)/cdin
	@if [ -d "$(OUT_DIR)/data" ]; then \
		install -dm755 $(DESTDIR)$(DATADIR); \
		cp -rL "$(OUT_DIR)/data/." $(DESTDIR)$(DATADIR)/; \
	fi
	@install -dm755 $(DESTDIR)$(BINDIR)
	@ln -sf $(LIBDIR)/cdin $(DESTDIR)$(BINDIR)/cdin
	@echo 'Installed to $(DESTDIR)$(PREFIX)'

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/cdin
	@rm -rf $(DESTDIR)$(LIBDIR)
	@echo 'Removed from $(DESTDIR)$(PREFIX)'
