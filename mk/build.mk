build: _check_deps $(OUT)
	$(call log_ok,Built $(OUT)  [SDL$(SDL_VERSION) | Lua $(LUA_FOUND_VERSION) | $(BUILD) | $(VERSION)])

$(OUT): $(OBJS)
	$(call log_step,LD,$@)
	@$(CC) $(OBJS) -o $@ $(LDFLAGS)
$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(call log_step,CC,$<)
	@$(CC) $(CFLAGS) -MMD -MP -c $< -o $@
ifeq ($(HAS_RESOURCE),1)
$(RES_OBJ): $(RES_SRC)
	@mkdir -p $(dir $@)
	$(call log_step,RC,$<)
	@$(WINDRES) $< -O coff -o $@
endif
-include $(DEPS)
debug:
	$(MAKE) BUILD=debug
debug-san:
	$(MAKE) BUILD=debug SANITIZE=1