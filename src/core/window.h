#ifndef WINDOW_H
#define WINDOW_H

#include <SDL3/SDL.h>
#include <stdbool.h>

/*
 * Create the main application window.
 *
 * The window is created borderless: cdin draws its own VSCode-style
 * title bar entirely from Lua (see data/core/titlebar.lua) and tells
 * this module, via window_set_hit_regions(), which on-screen rectangles
 * are "drag the window" vs. "click a caption button" vs. plain client
 * area. A small fixed border around the edges is always reserved for
 * resize handles so the window stays resizable despite having no OS
 * decorations.
 *
 * w, h: initial size in pixels (logical).
 * Returns NULL on failure.
 */
SDL_Window *window_create(int w, int h);

/*
 * Set the window icon from the embedded icon.inl file.
 * No-op on Windows (icon comes from the .rc resource).
 */
void window_set_icon(SDL_Window *win);

/*
 * Install the SDL_HitTest callback that powers the custom title bar.
 * Safe to call multiple times; only does real work once per window.
 */
void window_install_hittest(SDL_Window *win);

/*
 * Tell the hit-test callback where the draggable caption area is and
 * which rectangles within it are actually buttons (so clicks on the
 * buttons are reported as normal clicks instead of starting a window
 * drag). Coordinates are in window-local logical pixels, matching the
 * coordinates cdin already uses for mouse events.
 *
 * `buttons` may be NULL if `button_count` is 0.
 */
typedef struct {
  int x, y, w, h;
} WindowRect;

void window_set_hit_regions(int titlebar_height,
                             const WindowRect *buttons,
                             int button_count);

/* Caption-button actions, called from Lua via system.* bindings. */
void window_minimize(SDL_Window *win);
void window_toggle_maximize(SDL_Window *win);
bool window_is_maximized(SDL_Window *win);

#endif
