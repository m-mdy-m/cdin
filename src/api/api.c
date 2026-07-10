#include "api.h"

#include "../core/logger.h"
#include "../search/find.h"
#include "../fs/ops.h"
#include "../fs/path.h"

int luaopen_system(lua_State *L);
int luaopen_renderer(lua_State *L);

static const luaL_Reg eager_libs[] = {
  { "system",   luaopen_system   },
  { "renderer", luaopen_renderer },
  { "search",   luaopen_search   },
  { NULL, NULL }
};

static const luaL_Reg lazy_libs[] = {
  { "fs",   luaopen_fs   },
  { "path", luaopen_path },
  { NULL, NULL }
};


void api_load_libs(lua_State *L) {
  log_debug("api: registering native Lua libraries");

  for (int i = 0; eager_libs[i].name; i++) {
    luaL_requiref(L, eager_libs[i].name, eager_libs[i].func, 1);
    lua_pop(L, 1);
    log_trace("api: eager lib \"%s\" ready", eager_libs[i].name);
  }
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  for (int i = 0; lazy_libs[i].name; i++) {
    lua_pushcfunction(L, lazy_libs[i].func);
    lua_setfield(L, -2, lazy_libs[i].name);
    log_trace("api: lazy lib \"%s\" preloaded", lazy_libs[i].name);
  }
  lua_pop(L, 2);   /* pop preload, package */

  log_info("api: %d eager + %d lazy native libraries registered",
           (int)(sizeof(eager_libs) / sizeof(eager_libs[0]) - 1),
           (int)(sizeof(lazy_libs)  / sizeof(lazy_libs[0])  - 1));
}