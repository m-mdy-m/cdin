#include "search.h"
#include "../core/logger.h"

#include <ctype.h>
#include <string.h>


static int f_fuzzy_match(lua_State *L) {
  const char *str = luaL_checkstring(L, 1);
  const char *ptn = luaL_checkstring(L, 2);
  int score = 0, run = 0;
  while (*str && *ptn) {
    while (*str == ' ') str++;
    while (*ptn == ' ') ptn++;
    if (tolower((unsigned char)*str) == tolower((unsigned char)*ptn)) {
      score += run * 10 - (*str != *ptn);
      run++;
      ptn++;
    } else {
      score -= 10;
      run = 0;
    }
    str++;
  }
  if (*ptn) return 0;
  lua_pushnumber(L, score - (int)strlen(str));
  return 1;
}


static const luaL_Reg lib[] = {
  { "fuzzy_match", f_fuzzy_match },
  { NULL, NULL }
};

int luaopen_search(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}