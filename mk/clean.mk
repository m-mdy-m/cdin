clean:
	$(call log_step,RM,$(BUILD_DIR))
	@rm -rf $(BUILD_DIR)
distclean:
	$(call log_step,RM,build/)
	@rm -rf build/