#ifndef SEARCH_FIND_H
#define SEARCH_FIND_H

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
int fuzzy_match_c(const char *str, const char *ptn, int *score);
int luaopen_search(lua_State *L);

#endif /* SEARCH_FIND_H */