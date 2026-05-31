#include <SDL3/SDL.h>
#include <stdbool.h>
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <sys/stat.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "api.h"
#include "../rendrer/rendrer_cache.h"

#ifndef _WIN32
  #include <unistd.h>
#else
  #include <windows.h>
  #define realpath(x, y) _fullpath(y, x, MAX_PATH)
#endif

extern SDL_Window *window;


static const char *button_name(int button) {
  switch (button) {
    case 1:  return "left";
    case 2:  return "middle";
    case 3:  return "right";
    default: return "?";
  }
}

static char *key_name(char *dst, int sym) {
  const char *name = SDL_GetKeyName(sym);
  strncpy(dst, name, 15);
  dst[15] = '\0';
  for (char *p = dst; *p; p++) {
    *p = (char)tolower((unsigned char)*p);
  }
  return dst;
}


static int f_poll_event(lua_State *L) {
  char buf[16];
  SDL_Event e;

top:
  if (!SDL_PollEvent(&e)) {
    return 0;
  }

  switch (e.type) {
    /* ── quit ── */
    case SDL_EVENT_QUIT:
      lua_pushstring(L, "quit");
      return 1;

    /* ── window events (SDL3: separate event types) ── */
    case SDL_EVENT_WINDOW_RESIZED:
      lua_pushstring(L, "resized");
      lua_pushnumber(L, e.window.data1);
      lua_pushnumber(L, e.window.data2);
      return 3;

    case SDL_EVENT_WINDOW_EXPOSED:
      rencache_invalidate();
      lua_pushstring(L, "exposed");
      return 1;

    case SDL_EVENT_WINDOW_FOCUS_GAINED:
      /* Flush queued key-down events to avoid spurious tab presses */
      SDL_FlushEvents(SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_DOWN);
      goto top;

    /* ── file drop ── */
    case SDL_EVENT_DROP_FILE: {
      float mx, my;
      SDL_GetGlobalMouseState(&mx, &my);
      float wx, wy;
      SDL_GetWindowPosition(window, (int*)&wx, (int*)&wy);
      lua_pushstring(L, "filedropped");
      lua_pushstring(L, e.drop.data);
      lua_pushnumber(L, mx - wx);
      lua_pushnumber(L, my - wy);
      SDL_free(e.drop.data);
      return 4;
    }

    /* ── keyboard ── */
    case SDL_EVENT_KEY_DOWN:
      lua_pushstring(L, "keypressed");
      lua_pushstring(L, key_name(buf, e.key.key));
      return 2;

    case SDL_EVENT_KEY_UP:
      lua_pushstring(L, "keyreleased");
      lua_pushstring(L, key_name(buf, e.key.key));
      return 2;

    case SDL_EVENT_TEXT_INPUT:
      lua_pushstring(L, "textinput");
      lua_pushstring(L, e.text.text);
      return 2;

    /* ── mouse ── */
    case SDL_EVENT_MOUSE_BUTTON_DOWN:
      if (e.button.button == 1) SDL_CaptureMouse(true);
      lua_pushstring(L, "mousepressed");
      lua_pushstring(L, button_name(e.button.button));
      lua_pushnumber(L, e.button.x);
      lua_pushnumber(L, e.button.y);
      lua_pushnumber(L, e.button.clicks);
      return 5;

    case SDL_EVENT_MOUSE_BUTTON_UP:
      if (e.button.button == 1) SDL_CaptureMouse(false);
      lua_pushstring(L, "mousereleased");
      lua_pushstring(L, button_name(e.button.button));
      lua_pushnumber(L, e.button.x);
      lua_pushnumber(L, e.button.y);
      return 4;

    case SDL_EVENT_MOUSE_MOTION:
      lua_pushstring(L, "mousemoved");
      lua_pushnumber(L, e.motion.x);
      lua_pushnumber(L, e.motion.y);
      lua_pushnumber(L, e.motion.xrel);
      lua_pushnumber(L, e.motion.yrel);
      return 5;

    case SDL_EVENT_MOUSE_WHEEL:
      lua_pushstring(L, "mousewheel");
      lua_pushnumber(L, e.wheel.y);
      return 2;

    default:
      goto top;
  }

  return 0;
}


static int f_wait_event(lua_State *L) {
  double n = luaL_checknumber(L, 1);
  lua_pushboolean(L, SDL_WaitEventTimeout(NULL, (Sint32)(n * 1000)));
  return 1;
}


/* ── cursor ── */
static SDL_Cursor *cursor_cache[8];

static const char *cursor_opts[] = {
  "arrow", "ibeam", "sizeh", "sizev", "hand", NULL
};

static const SDL_SystemCursor cursor_enums[] = {
  SDL_SYSTEM_CURSOR_DEFAULT,
  SDL_SYSTEM_CURSOR_TEXT,
  SDL_SYSTEM_CURSOR_EW_RESIZE,
  SDL_SYSTEM_CURSOR_NS_RESIZE,
  SDL_SYSTEM_CURSOR_POINTER,
};

static int f_set_cursor(lua_State *L) {
  int opt = luaL_checkoption(L, 1, "arrow", cursor_opts);
  SDL_SystemCursor id = cursor_enums[opt];
  if (!cursor_cache[opt]) {
    cursor_cache[opt] = SDL_CreateSystemCursor(id);
  }
  SDL_SetCursor(cursor_cache[opt]);
  return 0;
}


static int f_set_window_title(lua_State *L) {
  SDL_SetWindowTitle(window, luaL_checkstring(L, 1));
  return 0;
}


static const char *window_opts[] = { "normal", "maximized", "fullscreen", NULL };

static int f_set_window_mode(lua_State *L) {
  int n = luaL_checkoption(L, 1, "normal", window_opts);
  if (n == 0) {
    SDL_RestoreWindow(window);
    SDL_SetWindowFullscreen(window, false);
  } else if (n == 1) {
    SDL_MaximizeWindow(window);
  } else {
    SDL_SetWindowFullscreen(window, true);
  }
  return 0;
}


static int f_window_has_focus(lua_State *L) {
  Uint32 flags = SDL_GetWindowFlags(window);
  lua_pushboolean(L, (flags & SDL_WINDOW_INPUT_FOCUS) != 0);
  return 1;
}


static int f_show_confirm_dialog(lua_State *L) {
  const char *title = luaL_checkstring(L, 1);
  const char *msg   = luaL_checkstring(L, 2);

#ifdef _WIN32
  int id = MessageBox(0, msg, title, MB_YESNO | MB_ICONWARNING);
  lua_pushboolean(L, id == IDYES);
#else
  SDL_MessageBoxButtonData buttons[] = {
    { SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT, 1, "Yes" },
    { SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT, 0, "No"  },
  };
  SDL_MessageBoxData data = {
    .title      = title,
    .message    = msg,
    .numbuttons = 2,
    .buttons    = buttons,
  };
  int buttonid = 0;
  SDL_ShowMessageBox(&data, &buttonid);
  lua_pushboolean(L, buttonid == 1);
#endif
  return 1;
}


static int f_chdir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  if (!SDL_SetCurrentDirectory(path)) {
    luaL_error(L, "chdir() failed: %s", SDL_GetError());
  }
  return 0;
}


static int f_list_dir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  DIR *dir = opendir(path);
  if (!dir) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_newtable(L);
  int i = 1;
  struct dirent *entry;
  while ((entry = readdir(dir))) {
    if (strcmp(entry->d_name, ".")  == 0) continue;
    if (strcmp(entry->d_name, "..") == 0) continue;
    lua_pushstring(L, entry->d_name);
    lua_rawseti(L, -2, i++);
  }
  closedir(dir);
  return 1;
}


static int f_absolute_path(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  char *res = realpath(path, NULL);
  if (!res) return 0;
  lua_pushstring(L, res);
  free(res);
  return 1;
}


static int f_get_file_info(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  struct stat s;
  if (stat(path, &s) < 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_newtable(L);
  lua_pushnumber(L, (lua_Number)s.st_mtime);
  lua_setfield(L, -2, "modified");
  lua_pushnumber(L, (lua_Number)s.st_size);
  lua_setfield(L, -2, "size");
  if      (S_ISREG(s.st_mode)) lua_pushstring(L, "file");
  else if (S_ISDIR(s.st_mode)) lua_pushstring(L, "dir");
  else                          lua_pushnil(L);
  lua_setfield(L, -2, "type");
  return 1;
}


static int f_get_clipboard(lua_State *L) {
  char *text = SDL_GetClipboardText();
  if (!text) return 0;
  lua_pushstring(L, text);
  SDL_free(text);
  return 1;
}

static int f_set_clipboard(lua_State *L) {
  SDL_SetClipboardText(luaL_checkstring(L, 1));
  return 0;
}


static int f_get_time(lua_State *L) {
  double t = (double)SDL_GetPerformanceCounter()
           / (double)SDL_GetPerformanceFrequency();
  lua_pushnumber(L, t);
  return 1;
}

static int f_sleep(lua_State *L) {
  double n = luaL_checknumber(L, 1);
  SDL_Delay((Uint32)(n * 1000));
  return 0;
}


static int f_exec(lua_State *L) {
  size_t len;
  const char *cmd = luaL_checklstring(L, 1, &len);
  char *buf = malloc(len + 32);
  if (!buf) luaL_error(L, "buffer allocation failed");
#ifdef _WIN32
  snprintf(buf, len + 32, "cmd /c \"%s\"", cmd);
  WinExec(buf, SW_HIDE);
#else
  snprintf(buf, len + 32, "%s &", cmd);
  int r = system(buf); (void)r;
#endif
  free(buf);
  return 0;
}


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
  { "poll_event",          f_poll_event          },
  { "wait_event",          f_wait_event          },
  { "set_cursor",          f_set_cursor          },
  { "set_window_title",    f_set_window_title    },
  { "set_window_mode",     f_set_window_mode     },
  { "window_has_focus",    f_window_has_focus    },
  { "show_confirm_dialog", f_show_confirm_dialog },
  { "chdir",               f_chdir               },
  { "list_dir",            f_list_dir            },
  { "absolute_path",       f_absolute_path       },
  { "get_file_info",       f_get_file_info       },
  { "get_clipboard",       f_get_clipboard       },
  { "set_clipboard",       f_set_clipboard       },
  { "get_time",            f_get_time            },
  { "sleep",               f_sleep               },
  { "exec",                f_exec                },
  { "fuzzy_match",         f_fuzzy_match         },
  { NULL, NULL }
};

int luaopen_system(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}