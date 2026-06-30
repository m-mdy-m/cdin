/*
 * main.c — cdin entry point
 *
 * Responsibilities:
 *   1. Logging bootstrap
 *   2. SDL3 init
 *   3. Window creation (via window.h) — borderless, custom title bar
 *   4. Renderer init
 *   5. Lua VM bootstrap (via lua_connector.h)
 *   6. Run the frame loop (driven from Lua)
 *   7. Clean shutdown
 *
 * Keep this file short. All real logic lives in Lua (data/core/) or in
 * the C modules it calls through the system/renderer APIs.
 */

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

  /* ── window (borderless; Lua draws its own title bar) ── */
  SDL_DisplayID display = SDL_GetPrimaryDisplay();
  const SDL_DisplayMode *dm = SDL_GetCurrentDisplayMode(display);
  int win_w = dm ? (int)(dm->w * 0.8f) : 1280;
  int win_h = dm ? (int)(dm->h * 0.8f) : 800;

  window = SDL_CreateWindow(
    "", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, dm.w * 0.8, dm.h * 0.8,
    SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_HIDDEN);
  init_window_icon();
  ren_init(window);

  /* ── HiDPI scale ── */
  double scale = utils_get_scale();

  /* ── Lua VM ── */
  lua_State *L = luaL_newstate();
  if (!L) {
    log_fatal("failed to create Lua state");
    SDL_DestroyWindow(window);
    if (log_fp) fclose(log_fp);
    return EXIT_FAILURE;
  }
  luaL_openlibs(L);
  api_load_libs(L);

  /* expose globals (ARGS, VERSION, PLATFORM, SCALE, EXEFILE, EXEDIR) */
  lua_setup_globals(L, argc, argv, scale, exefile);

  /* run core — this blocks until the user quits */
  lua_run_core(L);

  /* ── cleanup ── */
  log_info("cdin shutting down cleanly");
  lua_close(L);
  SDL_DestroyWindow(window);
  if (log_fp) fclose(log_fp);
  return EXIT_SUCCESS;
}
