#include "api.h"

#include "../helpers/logger.h"

int luaopen_system(lua_State *L);
int luaopen_renderer(lua_State *L);

static const luaL_Reg libs[] = {
  { "system",   luaopen_system   },
  { "renderer", luaopen_renderer },
  { NULL, NULL }
};


void api_load_libs(lua_State *L) {
  log_debug("api: registering native Lua libraries");
  for (int i = 0; libs[i].name; i++) {
    luaL_requiref(L, libs[i].name, libs[i].func, 1);
    lua_pop(L, 1); 
    log_trace("api: registered library \"%s\"", libs[i].name);
  }
  log_info("api: %d native libraries ready", (int)(sizeof(libs) / sizeof(libs[0]) - 1));
}
