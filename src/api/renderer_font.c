#include "api.h"
#include "../rendrer/renderer.h"
#include "../rendrer/rendrer_cache.h"
#include "../helpers/logger.h"


static int f_load(lua_State *L) {
  const char *filename = luaL_checkstring(L, 1);
  float size           = (float)luaL_checknumber(L, 2);
  log_debug("renderer.font: load(\"%s\", %.1f)", filename, size);

  RenFont **self = lua_newuserdata(L, sizeof(*self));
  luaL_setmetatable(L, API_TYPE_FONT);
  *self = ren_load_font(filename, size);
  if (!*self) {
    log_error("renderer.font: load(\"%s\") failed", filename);
    luaL_error(L, "failed to load font \"%s\"", filename);
  }
  log_info("renderer.font: loaded \"%s\" at %.1fpx (height=%dpx)",
           filename, size, ren_get_font_height(*self));
  return 1;
}


static int f_set_tab_width(lua_State *L) {
  RenFont **self = luaL_checkudata(L, 1, API_TYPE_FONT);
  int n          = (int)luaL_checknumber(L, 2);
  log_trace("renderer.font: set_tab_width(%d)", n);
  ren_set_font_tab_width(*self, n);
  return 0;
}


static int f_gc(lua_State *L) {
  RenFont **self = luaL_checkudata(L, 1, API_TYPE_FONT);
  if (*self) {
    log_debug("renderer.font: __gc — queuing font (size=%.1f) for deletion",
              ren_get_font_size(*self));
    rencache_free_font(*self);
    *self = NULL;
  }
  return 0;
}


static int f_get_width(lua_State *L) {
  RenFont **self  = luaL_checkudata(L, 1, API_TYPE_FONT);
  const char *text = luaL_checkstring(L, 2);
  lua_pushnumber(L, ren_get_font_width(*self, text));
  return 1;
}


static int f_get_height(lua_State *L) {
  RenFont **self = luaL_checkudata(L, 1, API_TYPE_FONT);
  lua_pushnumber(L, ren_get_font_height(*self));
  return 1;
}


static const luaL_Reg lib[] = {
  { "__gc",          f_gc            },
  { "load",          f_load          },
  { "set_tab_width", f_set_tab_width },
  { "get_width",     f_get_width     },
  { "get_height",    f_get_height    },
  { NULL, NULL }
};

int luaopen_renderer_font(lua_State *L) {
  log_trace("api: registering Font metatable (%s)", API_TYPE_FONT);
  luaL_newmetatable(L, API_TYPE_FONT);
  luaL_setfuncs(L, lib, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  return 1;
}