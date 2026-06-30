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
#include "core/window.h"
#include "core/lua_connector.h"
#include "helpers/logger.h"
#include "initial.h"
#include "rendrer/renderer.h"
#include "utils.h"

/* Exposed globally so system.c / renderer.c can reach it */
SDL_Window *window;


/* stderr gets INFO and above so a terminal launch shows useful status
 * without being noisy; everything from TRACE up also goes to cdin.log
 * next to the binary, so crashes or odd behaviour can be diagnosed
 * after the fact instead of just vanishing. */
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

  /* ── platform setup (DPI awareness on Windows, no-op elsewhere) ── */
  cdin_init_setup();

  /* ── SDL3 init ── */
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
    /* fallback: physical mode / content-scale — better than a hardcoded guess */
    const SDL_DisplayMode *dm = SDL_GetCurrentDisplayMode(display);
    float dscale = SDL_GetDisplayContentScale(display);
    if (dscale < 0.5f) dscale = 1.0f;
    win_w = dm ? (int)(dm->w * 0.8f / dscale) : 1280;
    win_h = dm ? (int)(dm->h * 0.8f / dscale) : 800;
  }

  /* SDL3 only delivers SDL_EVENT_TEXT_INPUT once text input is
   * explicitly started for the window (unlike SDL2, where it was on
   * by default). Without this, typing in the editor does nothing. */
  SDL_StartTextInput(window);

  /* ── renderer (software, via SDL surface) ── */
  ren_init(window);

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

  lua_setup_globals(L, argc, argv, scale, exefile);
  lua_run_core(L);
  log_info("cdin shutting down cleanly");
  lua_close(L);
  SDL_DestroyWindow(window);
  if (log_fp) fclose(log_fp);
  return EXIT_SUCCESS;
}