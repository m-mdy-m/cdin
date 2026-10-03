# Bundling: turning a cdin-x checkout into a runnable editor.
#
# This is the *only* place cdin knows cdin-x exists, and it knows it as a
# path: CDINX_DIR. Nothing under src/ or data/ refers to cdin-x, nothing is
# fetched, and no submodule or sibling lookup happens at runtime. A build
# takes a directory and reads files out of it.
#
#   CDINX_DIR   a cdin-x checkout. Defaults to ../cdin-x, i.e. the usual
#               two-checkouts-in-one-directory layout. Override with
#               `make CDINX_DIR=/elsewhere/cdin-x`.
#
# Targets:
#
#   make bin     compile the binary only. No cdin-x, no data/ assembly. This
#                is what you want when iterating on C, and it is what a build
#                machine runs when it is not producing a release.
#
#   make bundle  assemble $(OUT_DIR)/data: core/ plus the mandatory set that
#                cdin-x provides (the vim plugin, the default theme, the
#                fonts). Requires CDINX_DIR.
#
#   make         the default goal: bin, then bundle.

CDINX_DIR ?= $(abspath $(CURDIR)/../cdin-x)

.PHONY: bin bundle

bin: $(OUT)

bundle:
	@command -v $(PYTHON) >/dev/null 2>&1 || { \
		echo '✗ $(PYTHON) not found (needed to assemble data/)'; exit 1; }
	@$(PYTHON) scripts/assemble_data.py \
		--src data \
		--out "$(OUT_DIR)/data" \
		--cdinx "$(CDINX_DIR)"

# `make` alone: a runnable editor, not just a binary.
build: bin bundle
	@printf '\n✓ Built %s\n\n' '$(OUT)'
