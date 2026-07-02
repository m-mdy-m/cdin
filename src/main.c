#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL3/SDL.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "api/api.h"
#include "renderer.h"

#ifdef _WIN32
  #include <windows.h>
#elif __linux__
  #include <unistd.h>
#elif __APPLE__
  #include <mach-o/dyld.h>
#endif


SDL_Window *window;

int main(int argc, char **argv) {
#ifdef _WIN32
  HINSTANCE lib = LoadLibrary("user32.dll");
  int (*SetProcessDPIAware)() = (void*) GetProcAddress(lib, "SetProcessDPIAware");
  SetProcessDPIAware();
#endif

  SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS);
  SDL_EnableScreenSaver();
  SDL_EventState(SDL_DROPFILE, SDL_ENABLE);
  atexit(SDL_Quit);
  SDL_DisplayID display = SDL_GetPrimaryDisplay();
  SDL_Rect usable = {0};
  int win_w, win_h;
  if (SDL_GetDisplayUsableBounds(display, &usable) && usable.w > 0) {
    win_w = (int)(usable.w * 0.8f);
    win_h = (int)(usable.h * 0.8f);
  } else {
    /* fallback: physical mode / content-scale — better than a hardcoded guess */
    const SDL_DisplayMode *dm = SDL_GetCurrentDisplayMode(display);
    float dscale = SDL_GetDisplayContentScale(display);
    if (dscale < 0.5f) dscale = 1.0f;
    win_w = dm ? (int)(dm->w * 0.8f / dscale) : 1280;
    win_h = dm ? (int)(dm->h * 0.8f / dscale) : 800;
  }

  window = SDL_CreateWindow(
    "", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, dm.w * 0.8, dm.h * 0.8,
    SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_HIDDEN);
  init_window_icon();
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