#ifndef LUA_CONNECTOR_H
#define LUA_CONNECTOR_H

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

/*
 * Set all Lua globals that the core Lua scripts expect:
 * ARGS, VERSION, PLATFORM, SCALE, EXEFILE
 */
void lua_setup_globals(lua_State *L, int argc, char **argv, double scale, const char *exefile);

/*
 * Run the Lua bootstrap: load core, call core.init(), core.run().
 * Blocks until the editor exits.
 */
void lua_run_core(lua_State *L);

#endif