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
PYTHON ?= python3

.PHONY: bin bundle

# The compile. Same rule as $(OUT) in build.mk; bin is the name to type when
# you want the binary without the data assembly.
bin: $(OUT)

# data/ next to the binary. Recreated on every build, not only when missing:
# the source core/ changes constantly, and a link that is created once and
# then assumed correct is exactly the stale-data bug the old symlink
# dance in build.mk was working around.
#
# assemble_data.py owns the rules here — what a symlink is, what happens to
# an old symlink left by a previous build, and what the error is when
# cdin-x is not where CDINX_DIR says. The Makefile only says what to run.
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
