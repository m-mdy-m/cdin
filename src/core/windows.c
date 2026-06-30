#include "window.h"
#include "../helpers/logger.h"

#include <string.h>

#define MAX_HIT_BUTTONS 8

/* Border thickness (logical px) reserved around the borderless window
 * for resize handles. Kept small so it doesn't feel like "fat" OS
 * chrome, but large enough to grab comfortably with a mouse. */
#define RESIZE_BORDER 6

static struct {
  bool installed;
  int titlebar_height;
  WindowRect buttons[MAX_HIT_BUTTONS];
  int button_count;
} hit_state;


static SDL_HitTestResult SDLCALL hit_test_cb(SDL_Window *win, const SDL_Point *area, void *data) {
  (void)data;

  int w, h;
  SDL_GetWindowSize(win, &w, &h);

  int x = area->x;
  int y = area->y;

  /* Maximized windows have no edges to grab; let the OS treat the
   * whole thing as normal client area aside from the caption. */
  bool maximized = (SDL_GetWindowFlags(win) & SDL_WINDOW_MAXIMIZED) != 0;

  if (!maximized) {
    bool on_left   = x < RESIZE_BORDER;
    bool on_right  = x >= w - RESIZE_BORDER;
    bool on_top    = y < RESIZE_BORDER;
    bool on_bottom = y >= h - RESIZE_BORDER;

    if (on_top    && on_left)  return SDL_HITTEST_RESIZE_TOPLEFT;
    if (on_top    && on_right) return SDL_HITTEST_RESIZE_TOPRIGHT;
    if (on_bottom && on_left)  return SDL_HITTEST_RESIZE_BOTTOMLEFT;
    if (on_bottom && on_right) return SDL_HITTEST_RESIZE_BOTTOMRIGHT;
    if (on_left)   return SDL_HITTEST_RESIZE_LEFT;
    if (on_right)  return SDL_HITTEST_RESIZE_RIGHT;
    if (on_top)    return SDL_HITTEST_RESIZE_TOP;
    if (on_bottom) return SDL_HITTEST_RESIZE_BOTTOM;
  }

  /* Caption buttons (minimize/maximize/close) must stay clickable,
   * not draggable, even though they live inside the title bar strip. */
  for (int i = 0; i < hit_state.button_count; i++) {
    const WindowRect *r = &hit_state.buttons[i];
    if (x >= r->x && x < r->x + r->w && y >= r->y && y < r->y + r->h) {
      return SDL_HITTEST_NORMAL;
    }
  }

  if (y < hit_state.titlebar_height) {
    return SDL_HITTEST_DRAGGABLE;
  }

  return SDL_HITTEST_NORMAL;
}


SDL_Window *window_create(int w, int h) {
  SDL_Window *win = SDL_CreateWindow(
    "cdin",
    w, h,
    SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY |
    SDL_WINDOW_HIDDEN | SDL_WINDOW_BORDERLESS
  );

  if (!win) {
    log_fatal("failed to create window: %s", SDL_GetError());
    return NULL;
  }

  log_info("window created (%dx%d, borderless)", w, h);
  window_install_hittest(win);
  return win;
}


void window_install_hittest(SDL_Window *win) {
  if (hit_state.installed || !win) return;
  if (!SDL_SetWindowHitTest(win, hit_test_cb, NULL)) {
    /* Not fatal: the window still works, it just can't be resized by
     * dragging an edge on platforms that don't support custom hit
     * testing. The title bar buttons still call the regular window
     * commands below. */
    log_warn("SDL_SetWindowHitTest failed: %s", SDL_GetError());
    return;
  }
  hit_state.installed = true;
}


void window_set_hit_regions(int titlebar_height, const WindowRect *buttons, int button_count) {
  hit_state.titlebar_height = titlebar_height;
  if (button_count > MAX_HIT_BUTTONS) {
    log_warn("window_set_hit_regions: %d buttons requested, clamping to %d",
             button_count, MAX_HIT_BUTTONS);
    button_count = MAX_HIT_BUTTONS;
  }
  hit_state.button_count = button_count;
  if (button_count > 0 && buttons) {
    memcpy(hit_state.buttons, buttons, sizeof(WindowRect) * (size_t)button_count);
  }
}


void window_minimize(SDL_Window *win) {
  if (!win) return;
  SDL_MinimizeWindow(win);
}


void window_toggle_maximize(SDL_Window *win) {
  if (!win) return;
  if (window_is_maximized(win)) {
    SDL_RestoreWindow(win);
  } else {
    SDL_MaximizeWindow(win);
  }
}


bool window_is_maximized(SDL_Window *win) {
  if (!win) return false;
  return (SDL_GetWindowFlags(win) & SDL_WINDOW_MAXIMIZED) != 0;
}


void window_set_icon(SDL_Window *win) {
#ifndef _WIN32
  /* icon.inl defines: const unsigned char icon_rgba[]; const unsigned icon_rgba_len; */
  #include "../../icon.inl"
  (void)icon_rgba_len;

  SDL_Surface *surf = SDL_CreateSurfaceFrom(
    64, 64,
    SDL_PIXELFORMAT_RGBA32,
    (void *)icon_rgba,
    64 * 4
  );

  if (surf) {
    SDL_SetWindowIcon(win, surf);
    SDL_DestroySurface(surf);
  } else {
    log_error("failed to create icon surface: %s", SDL_GetError());
  }
#else
  (void)win;
#endif
}
