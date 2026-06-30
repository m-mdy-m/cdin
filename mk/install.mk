.PHONY: install uninstall

install: build
	@install -dm755 $(DESTDIR)$(LIBDIR)
	@install -m755 $(OUT) $(DESTDIR)$(LIBDIR)/cdin
	@if [ -d data ]; then \
		install -dm755 $(DESTDIR)$(DATADIR); \
		cp -r data/. $(DESTDIR)$(DATADIR)/; \
	fi
	@install -dm755 $(DESTDIR)$(BINDIR)
	@ln -sf $(LIBDIR)/cdin $(DESTDIR)$(BINDIR)/cdin
	@echo 'Installed to $(DESTDIR)$(PREFIX)'

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/cdin
	@rm -rf $(DESTDIR)$(LIBDIR)
	@echo 'Removed from $(DESTDIR)$(PREFIX)'
