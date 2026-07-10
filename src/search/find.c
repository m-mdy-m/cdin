#include "find.h"

#include <ctype.h>
#include <string.h>

int fuzzy_match_c(const char *str, const char *ptn, int *score) {
  int s = 0, run = 0;
  const char *str0 = str;
  (void)str0;

  while (*str && *ptn) {
    while (*str == ' ') str++;
    while (*ptn == ' ') ptn++;
    if (!*str || !*ptn) break;

    if (tolower((unsigned char)*str) == tolower((unsigned char)*ptn)) {
      s += run * 10 - (*str != *ptn);
      run++;
      ptn++;
    } else {
      s -= 10;
      run = 0;
    }
    str++;
  }

  if (*ptn) return 0;   /* pattern not fully consumed */

  *score = s - (int)strlen(str);   /* length penalty */
  return 1;
}


static int f_fuzzy_match(lua_State *L) {
  const char *str = luaL_checkstring(L, 1);
  const char *ptn = luaL_checkstring(L, 2);
  int score;
  if (!fuzzy_match_c(str, ptn, &score)) return 0;
  lua_pushnumber(L, score);
  return 1;
}


static void ascii_lower(const char *src, size_t len, char *dst) {
  for (size_t i = 0; i < len; i++) {
    unsigned char c = (unsigned char)src[i];
    dst[i] = (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : (char)c;
  }
}

static int scan_range(lua_State *L,
                      int lines_idx, int find_idx,
                      lua_Integer from_line, lua_Integer from_col,
                      lua_Integer nlines,
                      const char *text, size_t text_len,
                      int is_pattern, int no_case,
                      lua_Integer *ls, lua_Integer *cs,
                      lua_Integer *le, lua_Integer *ce) {
  lua_Integer col = from_col;

  for (lua_Integer line = from_line; line <= nlines; line++) {
    lua_rawgeti(L, lines_idx, line);
    size_t line_len = 0;
    const char *line_text = lua_tolstring(L, -1, &line_len);
    if (!line_text) { lua_pop(L, 1); continue; }

    if (no_case) {
      luaL_Buffer b;
      char *buf = luaL_buffinitsize(L, &b, line_len);
      ascii_lower(line_text, line_len, buf);
      luaL_pushresultsize(&b, line_len);
      lua_replace(L, -2);
      line_text = lua_tolstring(L, -1, &line_len);
    }

    lua_pushvalue(L, find_idx);
    lua_pushlstring(L, line_text, line_len);
    lua_pushlstring(L, text, text_len);
    lua_pushinteger(L, col);
    lua_pushboolean(L, !is_pattern);
    lua_call(L, 4, 2);

    if (!lua_isnil(L, -2)) {
      lua_Integer s = lua_tointeger(L, -2);
      lua_Integer e = lua_tointeger(L, -1);
      lua_pop(L, 3);
      *ls = line; *cs = s; *le = line; *ce = e + 1;
      return 1;
    }

    lua_pop(L, 3);
    col = 1;
  }
  return 0;
}

static int f_find_in_lines(lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_Integer start_line = luaL_checkinteger(L, 2);
  lua_Integer start_col  = luaL_checkinteger(L, 3);
  size_t text_len = 0;
  const char *text = luaL_checklstring(L, 4, &text_len);
  int no_case    = lua_toboolean(L, 5);
  int is_pattern = lua_toboolean(L, 6);
  int wrap       = lua_toboolean(L, 7);

  lua_Integer nlines = luaL_len(L, 1);

  lua_getglobal(L, "string");
  lua_getfield(L, -1, "find");
  int find_idx = lua_gettop(L);
  lua_remove(L, find_idx - 1);
  find_idx -= 1;

  lua_Integer ls, cs, le, ce;

  if (scan_range(L, 1, find_idx, start_line, start_col, nlines,
                 text, text_len, is_pattern, no_case, &ls, &cs, &le, &ce)) {
    lua_pushinteger(L, ls); lua_pushinteger(L, cs);
    lua_pushinteger(L, le); lua_pushinteger(L, ce);
    return 4;
  }

  if (wrap) {
    if (scan_range(L, 1, find_idx, 1, 1, nlines,
                   text, text_len, is_pattern, no_case, &ls, &cs, &le, &ce)) {
      lua_pushinteger(L, ls); lua_pushinteger(L, cs);
      lua_pushinteger(L, le); lua_pushinteger(L, ce);
      return 4;
    }
  }

  lua_pushnil(L);
  return 1;
}


static const luaL_Reg lib[] = {
  { "find_in_lines", f_find_in_lines },
  { "fuzzy_match",   f_fuzzy_match   },
  { NULL, NULL }
};

int luaopen_search(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}