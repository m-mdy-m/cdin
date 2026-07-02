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
#include "../core/window.h"
#include "../helpers/logger.h"

#ifndef _WIN32
  #include <unistd.h>
#else
  #include <windows.h>
  #include <direct.h>
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
      SDL_FlushEvents(SDL_EVENT_TEXT_INPUT, SDL_EVENT_TEXT_INPUT);
      goto top;

    case SDL_EVENT_DROP_FILE: {
      float mx, my;
      SDL_GetGlobalMouseState(&mx, &my);
      int wx, wy;
      SDL_GetWindowPosition(window, &wx, &wy);
      lua_pushstring(L, "filedropped");
      lua_pushstring(L, e.drop.data);
      lua_pushnumber(L, mx - (float)wx);
      lua_pushnumber(L, my - (float)wy);
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
    log_debug("system: creating and caching cursor \"%s\"", cursor_opts[opt]);
    cursor_cache[opt] = SDL_CreateSystemCursor(id);
    if (!cursor_cache[opt]) {
      log_error("system: SDL_CreateSystemCursor(\"%s\") failed: %s", cursor_opts[opt], SDL_GetError());
    }
  }
  SDL_SetCursor(cursor_cache[opt]);
  return 0;
}


static int f_set_window_title(lua_State *L) {
  const char *title = luaL_checkstring(L, 1);
  log_trace("system: set window title to \"%s\"", title);
  SDL_SetWindowTitle(window, title);
  return 0;
}


static const char *window_opts[] = { "normal", "maximized", "fullscreen", NULL };

static int f_set_window_mode(lua_State *L) {
  int n = luaL_checkoption(L, 1, "normal", window_opts);
  log_debug("system: set window mode to \"%s\"", window_opts[n]);
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


static int f_window_minimize(lua_State *L) {
  (void)L;
  window_minimize(window);
  return 0;
}


static int f_window_toggle_maximize(lua_State *L) {
  (void)L;
  window_toggle_maximize(window);
  return 0;
}


static int f_window_is_maximized(lua_State *L) {
  lua_pushboolean(L, window_is_maximized(window));
  return 1;
}

static int f_set_hit_regions(lua_State *L) {
  int titlebar_height = (int)luaL_checknumber(L, 1);
  WindowRect buttons[8];
  int n = 0;

  if (!lua_isnoneornil(L, 2)) {
    luaL_checktype(L, 2, LUA_TTABLE);
    int len = (int)lua_rawlen(L, 2);
    for (int i = 1; i <= len && n < 8; i++) {
      lua_rawgeti(L, 2, i);
      if (lua_istable(L, -1)) {
        lua_rawgeti(L, -1, 1); buttons[n].x = (int)lua_tonumber(L, -1); lua_pop(L, 1);
        lua_rawgeti(L, -1, 2); buttons[n].y = (int)lua_tonumber(L, -1); lua_pop(L, 1);
        lua_rawgeti(L, -1, 3); buttons[n].w = (int)lua_tonumber(L, -1); lua_pop(L, 1);
        lua_rawgeti(L, -1, 4); buttons[n].h = (int)lua_tonumber(L, -1); lua_pop(L, 1);
        n++;
      }
      lua_pop(L, 1);
    }
  }

  window_set_hit_regions(titlebar_height, buttons, n);
  return 0;
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
  SDL_MessageBoxColorScheme scheme = {
    .colors = {
      [SDL_MESSAGEBOX_COLOR_BACKGROUND]        = { 14, 14, 14 },
      [SDL_MESSAGEBOX_COLOR_TEXT]              = { 208, 208, 208 },
      [SDL_MESSAGEBOX_COLOR_BUTTON_BORDER]     = { 58, 58, 58 },
      [SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND] = { 26, 26, 26 },
      [SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED]   = { 139, 127, 199 },
    },
  };
  SDL_MessageBoxData data = {
    .title       = title,
    .message     = msg,
    .numbuttons  = 2,
    .buttons     = buttons,
    .colorScheme = &scheme,
  };
  int buttonid = 0;
  if (!SDL_ShowMessageBox(&data, &buttonid)) {
    log_error("SDL_ShowMessageBox failed: %s", SDL_GetError());
  }
  lua_pushboolean(L, buttonid == 1);
#endif
  return 1;
}


static int f_chdir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
#ifdef _WIN32
  if (_chdir(path) != 0) {
    log_error("system.chdir(\"%s\") failed: %s", path, strerror(errno));
    luaL_error(L, "chdir() failed: %s", strerror(errno));
  }
#else
  if (chdir(path) != 0) {
    log_error("system.chdir(\"%s\") failed: %s", path, strerror(errno));
    luaL_error(L, "chdir() failed: %s", strerror(errno));
  }
#endif
  log_info("system: working directory changed to \"%s\"", path);
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
#ifdef _WIN32
  int wlen = MultiByteToWideChar(CP_UTF8, 0, cmd, -1, NULL, 0);
  wchar_t *wcmd = (wchar_t *)malloc(wlen * sizeof(wchar_t));
  if (!wcmd) luaL_error(L, "buffer allocation failed");
  MultiByteToWideChar(CP_UTF8, 0, cmd, -1, wcmd, wlen);

  STARTUPINFOW si = { 0 };
  si.cb = sizeof(si);
  PROCESS_INFORMATION pi = { 0 };
  CreateProcessW(NULL, wcmd, NULL, NULL, FALSE,
                 DETACHED_PROCESS | CREATE_NO_WINDOW,
                 NULL, NULL, &si, &pi);
  if (pi.hProcess) CloseHandle(pi.hProcess);
  if (pi.hThread)  CloseHandle(pi.hThread);
  free(wcmd);
#else
  char *buf = malloc(len + 32);
  if (!buf) luaL_error(L, "buffer allocation failed");
  snprintf(buf, len + 32, "%s &", cmd);
  int r = system(buf); (void)r;
  free(buf);
#endif
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
static int f_popen(lua_State *L) {
  const char *cmd = luaL_checkstring(L, 1);

#ifdef _WIN32
  int wlen = MultiByteToWideChar(CP_UTF8, 0, cmd, -1, NULL, 0);
  wchar_t *wcmd = (wchar_t *)malloc(wlen * sizeof(wchar_t));
  if (!wcmd) return luaL_error(L, "popen: out of memory");
  MultiByteToWideChar(CP_UTF8, 0, cmd, -1, wcmd, wlen);

  SECURITY_ATTRIBUTES sa = { sizeof(sa), NULL, TRUE };
  HANDLE hRead, hWrite;
  if (!CreatePipe(&hRead, &hWrite, &sa, 0)) {
    free(wcmd);
    lua_pushnil(L);
    return 1;
  }
  SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);

  STARTUPINFOW si = { 0 };
  si.cb          = sizeof(si);
  si.dwFlags     = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;
  si.hStdOutput  = hWrite;
  si.hStdError   = hWrite;  
  si.hStdInput   = GetStdHandle(STD_INPUT_HANDLE);

  PROCESS_INFORMATION pi = { 0 };
  BOOL ok = CreateProcessW(
    NULL, wcmd, NULL, NULL,
    TRUE,                         
    CREATE_NO_WINDOW,             
    NULL, NULL, &si, &pi);
  free(wcmd);
  CloseHandle(hWrite);           

  if (!ok) {
    CloseHandle(hRead);
    lua_pushnil(L);
    return 1;
  }

  luaL_Buffer b;
  luaL_buffinit(L, &b);
  char buf[4096];
  DWORD nread;
  while (ReadFile(hRead, buf, sizeof(buf), &nread, NULL) && nread > 0)
    luaL_addlstring(&b, buf, nread);

  CloseHandle(hRead);
  WaitForSingleObject(pi.hProcess, INFINITE);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);

  luaL_pushresult(&b);
  return 1;

#else
  FILE *fp = popen(cmd, "r");
  if (!fp) { lua_pushnil(L); return 1; }

  luaL_Buffer b;
  luaL_buffinit(L, &b);
  char buf[4096];
  size_t n;
  while ((n = fread(buf, 1, sizeof(buf), fp)) > 0)
    luaL_addlstring(&b, buf, n);
  pclose(fp);

  luaL_pushresult(&b);
  return 1;
#endif
}


static const luaL_Reg lib[] = {
  { "poll_event",            f_poll_event            },
  { "wait_event",            f_wait_event            },
  { "set_cursor",            f_set_cursor            },
  { "set_window_title",      f_set_window_title      },
  { "set_window_mode",       f_set_window_mode       },
  { "window_has_focus",      f_window_has_focus      },
  { "window_minimize",       f_window_minimize       },
  { "window_toggle_maximize",f_window_toggle_maximize},
  { "window_is_maximized",   f_window_is_maximized   },
  { "set_hit_regions",       f_set_hit_regions       },
  { "show_confirm_dialog",   f_show_confirm_dialog   },
  { "chdir",                 f_chdir                 },
  { "list_dir",              f_list_dir              },
  { "absolute_path",         f_absolute_path         },
  { "get_file_info",         f_get_file_info         },
  { "get_clipboard",         f_get_clipboard         },
  { "set_clipboard",         f_set_clipboard         },
  { "get_time",              f_get_time              },
  { "sleep",                 f_sleep                 },
  { "exec",                  f_exec                  },
  { "popen",                 f_popen                 },
  { "fuzzy_match",           f_fuzzy_match           },
  { NULL, NULL }
};

int luaopen_system(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}