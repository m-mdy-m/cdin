#ifndef LUA_CONNECTOR_H
#define LUA_CONNECTOR_H

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

void lua_setup_globals(lua_State *L, int argc, char **argv, double scale, const char *exefile);
void lua_run_core(lua_State *L);

#endif