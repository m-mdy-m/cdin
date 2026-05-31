#include "window.h"
#include <stdio.h>

SDL_Window *window_create(int w, int h) {
  SDL_Window *win = SDL_CreateWindow(
    "cdin",
    w, h,
    SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY | SDL_WINDOW_HIDDEN
  );

  if (!win) {
    fprintf(stderr, "cdin: failed to create window: %s\n", SDL_GetError());
    return NULL;
  }

  return win;
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
    fprintf(stderr, "cdin: failed to create icon surface: %s\n", SDL_GetError());
  }
#else
  (void)win;
#endif
}
