#include "api.h"

#include "../core/logger.h"
#include "../fs/fs.h"
#include "../search/search.h"

int luaopen_system(lua_State *L);
int luaopen_renderer(lua_State *L);

static const luaL_Reg libs[] = {
  { "system",   luaopen_system   },
  { "renderer", luaopen_renderer },
  { "fs",       luaopen_fs       },
  { "search",   luaopen_search   },
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