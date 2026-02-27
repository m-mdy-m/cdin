.PHONY: install uninstall

install: build
	@install -Dm755 $(OUT) $(DESTDIR)$(BINDIR)/cdin
	@if [ -d data ]; then \
		install -dm755 $(DESTDIR)$(DATADIR); \
		cp -r data/. $(DESTDIR)$(DATADIR)/; \
	fi
	@echo 'Installed to $(DESTDIR)$(PREFIX)'

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/cdin
	@rm -rf $(DESTDIR)$(DATADIR)
	@echo 'Removed from $(DESTDIR)$(PREFIX)'