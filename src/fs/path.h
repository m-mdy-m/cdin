#ifndef FS_PATH_H
#define FS_PATH_H

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

int path_absolute(const char *p, char *out, int out_size);
int luaopen_path(lua_State *L);

#endif 