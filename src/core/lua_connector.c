#include "lua_connector.h"
#include "../global_config.h"
#include "../helpers/logger.h"

#include <SDL3/SDL.h>
#include <stdio.h>

void lua_setup_globals(lua_State *L, int argc, char **argv,
                       double scale, const char *exefile) {
  /* ARGS table: ARGS[1] = argv[0], ARGS[2] = argv[1], ... */
  lua_newtable(L);
  for (int i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i + 1);
  }
  lua_setglobal(L, "ARGS");

  /* VERSION from global_config (set at compile time via mk/version.mk) */
  lua_pushstring(L, CDIN_APP_VERSION);
  lua_setglobal(L, "VERSION");

  /* COMMIT from global_config */
  lua_pushstring(L, CDIN_APP_COMMIT);
  lua_setglobal(L, "COMMIT");

  /* PLATFORM string from SDL */
  lua_pushstring(L, SDL_GetPlatform());
  lua_setglobal(L, "PLATFORM");

  /* SCALE: HiDPI scaling factor */
  lua_pushnumber(L, scale);
  lua_setglobal(L, "SCALE");

  /* EXEFILE: full path to the binary */
  lua_pushstring(L, exefile);
  lua_setglobal(L, "EXEFILE");
}

void lua_run_core(lua_State *L) {
  int err = luaL_dostring(L,
    "local core\n"
    "xpcall(function()\n"
    "  SCALE = tonumber(os.getenv('CDIN_SCALE')) or SCALE\n"
    "  PATHSEP = package.config:sub(1,1)\n"
    "  EXEDIR = EXEFILE:match('^(.+)[/\\\\\\\\].*$')\n"
    "  package.path = EXEDIR .. '/data/?.lua;' .. package.path\n"
    "  package.path = EXEDIR .. '/data/?/init.lua;' .. package.path\n"
    "  core = require('core')\n"
    "  core.init()\n"
    "  core.run()\n"
    "end, function(err)\n"
    "  print('Error: ' .. tostring(err))\n"
    "  print(debug.traceback(nil, 2))\n"
    "  if core and core.on_error then\n"
    "    pcall(core.on_error, err)\n"
    "  end\n"
    "  os.exit(1)\n"
    "end)\n"
  );

  if (err) {
    log_fatal("fatal Lua error: %s", lua_tostring(L, -1));
    lua_close(L);
  }
}
