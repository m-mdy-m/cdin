#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL3/SDL.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "api/api.h"
#include "core/window.h"
#include "lua/api.h"
#include "core/logger.h"
#include "core/boot.h"
#include "ui/renderer.h"
#include "core/utils.h"

SDL_Window *window;


static FILE *setup_logging(const char *exefile) {
  log_set_level(LOG_INFO);

  char dir[2048];
  strncpy(dir, exefile, sizeof(dir) - 1);
  dir[sizeof(dir) - 1] = '\0';

  char *slash = strrchr(dir, '/');
#ifdef _WIN32
  char *bslash = strrchr(dir, '\\');
  if (!slash || (bslash && bslash > slash)) slash = bslash;
#endif
  if (slash) *slash = '\0';

  char log_path[2080];
  snprintf(log_path, sizeof(log_path), "%s/cdin.log", slash ? dir : ".");

  FILE *fp = fopen(log_path, "a");
  if (fp) {
    log_add_fp(fp, LOG_TRACE);
  } else {
    log_warn("could not open %s for writing, file logging disabled", log_path);
  }
  return fp;
}


int main(int argc, char **argv) {
  char exefile[2048] = {0};
  utils_get_exe_filename(exefile, sizeof(exefile));
  FILE *log_fp = setup_logging(exefile);
  log_info("cdin starting");

  cdin_init_setup();
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
    log_fatal("SDL_Init failed: %s", SDL_GetError());
    if (log_fp) fclose(log_fp);
    return EXIT_FAILURE;
  }
  SDL_SetHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", "1");
  atexit(SDL_Quit);
  SDL_DisplayID display = SDL_GetPrimaryDisplay();
  SDL_Rect usable = {0};
  int win_w, win_h;
  if (SDL_GetDisplayUsableBounds(display, &usable) && usable.w > 0) {
    win_w = (int)(usable.w * 0.8f);
    win_h = (int)(usable.h * 0.8f);
  } else {
    const SDL_DisplayMode *dm = SDL_GetCurrentDisplayMode(display);
    float dscale = SDL_GetDisplayContentScale(display);
    if (dscale < 0.5f) dscale = 1.0f;
    win_w = dm ? (int)(dm->w * 0.8f / dscale) : 1280;
    win_h = dm ? (int)(dm->h * 0.8f / dscale) : 800;
  }

  window = window_create(win_w, win_h);
  if (!window) {
    log_fatal("window_create failed, exiting");
    if (log_fp) fclose(log_fp);
    return EXIT_FAILURE;
  }
  window_set_icon(window);

  SDL_StartTextInput(window);

  ren_init(window);

  double scale = utils_get_scale();

  lua_State *L = luaL_newstate();
  if (!L) {
    log_fatal("failed to create Lua state");
    SDL_DestroyWindow(window);
    if (log_fp) fclose(log_fp);
    return EXIT_FAILURE;
  }
  luaL_openlibs(L);
  api_load_libs(L);

  lua_setup_globals(L, argc, argv, scale, exefile);
  lua_run_core(L);
  log_info("cdin shutting down cleanly");
  lua_close(L);
  SDL_DestroyWindow(window);
  if (log_fp) fclose(log_fp);
  return EXIT_SUCCESS;
}