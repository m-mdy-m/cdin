#ifndef WINDOW_H
#define WINDOW_H

#include <SDL3/SDL.h>

SDL_Window *window_create(int w, int h);
void window_set_icon(SDL_Window *win);

#endif