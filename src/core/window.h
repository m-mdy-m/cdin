#ifndef WINDOW_H
#define WINDOW_H

#include <SDL3/SDL.h>

/*
 * Create the main application window.
 * w, h: initial size in pixels (logical).
 * Returns NULL on failure.
 */
SDL_Window *window_create(int w, int h);

/*
 * Set the window icon from the embedded icon.inl file.
 * No-op on Windows (icon comes from the .rc resource).
 */
void window_set_icon(SDL_Window *win);

#endif