run: build
	$(call log_step,RUN,$(OUT))
	@$(OUT)
run-debug: debug
	@$(MAKE) BUILD=debug _run_bin
_run_bin:
	@$(OUT)