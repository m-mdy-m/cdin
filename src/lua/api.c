#include "api.h"

#include <SDL3/SDL.h>
#include <stdlib.h>
#include <string.h>

#include "../core/config.h"
#include "../core/logger.h"


void lua_setup_globals(lua_State *L, int argc, char **argv, double scale, const char *exefile) {
  log_debug("lua_connector: pushing globals (argc=%d, scale=%.2f)", argc, scale);

  lua_newtable(L);
  for (int i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i + 1);
  }
  lua_setglobal(L, "ARGS");

  lua_pushstring(L, CDIN_APP_VERSION);
  lua_setglobal(L, "VERSION");

  lua_pushstring(L, SDL_GetPlatform());
  lua_setglobal(L, "PLATFORM");

  lua_pushnumber(L, scale);
  lua_setglobal(L, "SCALE");

  lua_pushstring(L, exefile);
  lua_setglobal(L, "EXEFILE");

  log_info("lua_connector: globals ready (VERSION=%s PLATFORM=%s SCALE=%.2f)",
           CDIN_APP_VERSION, SDL_GetPlatform(), scale);
}

static const char *BOOTSTRAP =
  "local core\n"
  "local ok, err = xpcall(function()\n"
  "  PATHSEP = package.config:sub(1, 1)\n"
  "  EXEDIR = EXEFILE:match('^(.+)[/\\\\].*$') or '.'\n"
  "  package.path = EXEDIR .. '/data/?.lua;' .. package.path\n"
  "  package.path = EXEDIR .. '/data/?/init.lua;' .. package.path\n"
  "  core = require('core')\n"
  "  core.init()\n"
  "  core.run()\n"
  "end, function(msg)\n"
  "  return tostring(msg) .. '\\n' .. debug.traceback(nil, 2)\n"
  "end)\n"
  "if not ok then\n"
  "  cdin_log_fatal(err)\n"
  "end\n";
static int f_cdin_log_fatal(lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  log_fatal("lua error (unhandled):\n%s", msg ? msg : "(no message)");
  return 0;
}


void lua_run_core(lua_State *L) {
  lua_pushcfunction(L, f_cdin_log_fatal);
  lua_setglobal(L, "cdin_log_fatal");

  log_info("lua_connector: booting core.init() / core.run()");

  if (luaL_dostring(L, BOOTSTRAP) != LUA_OK) {
    const char *msg = lua_tostring(L, -1);
    log_fatal("lua_connector: bootstrap failed: %s", msg ? msg : "(unknown)");
    lua_pop(L, 1);
  }

  log_info("lua_connector: core.run() returned, shutting down");
}
