#include <stdio.h>
#include <stdbool.h>
#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* stb_truetype — single-header font rasterizer */
#define STB_TRUETYPE_IMPLEMENTATION
#include "../../lib/stb/stb_truetype.h"

#include "renderer.h"
#include "../helpers/logger.h"

#define MAX_GLYPHSET 256

struct RenImage {
  RenColor *pixels;
  int width, height;
};

typedef struct {
  RenImage *image;
  stbtt_bakedchar glyphs[256];
} GlyphSet;

struct RenFont {
  void *data;
  stbtt_fontinfo stbfont;
  GlyphSet *sets[MAX_GLYPHSET];
  float size;
  int height;
};

static SDL_Window   *window;
static SDL_Surface  *surface; 
static struct { int left, top, right, bottom; } clip;


static void *check_alloc(void *ptr) {
  if (!ptr) {
    log_fatal("memory allocation failed");
    exit(EXIT_FAILURE);
  }
  return ptr;
}

static const char *utf8_to_codepoint(const char *p, unsigned *dst) {
  unsigned res, n;
  switch (*p & 0xf0) {
    case 0xf0: res = *p & 0x07; n = 3; break;
    case 0xe0: res = *p & 0x0f; n = 2; break;
    case 0xd0:
    case 0xc0: res = *p & 0x1f; n = 1; break;
    default:   res = *p;        n = 0; break;
  }
  while (n--) res = (res << 6) | (*(++p) & 0x3f);
  *dst = res;
  return p + 1;
}

void ren_init(SDL_Window *win) {
  assert(win);
  window = win;
  surface = SDL_GetWindowSurface(window);
  assert(surface);
  ren_set_clip_rect((RenRect){ 0, 0, surface->w, surface->h });
}

void ren_update_rects(RenRect *rects, int count) {
  SDL_UpdateWindowSurfaceRects(window, (SDL_Rect *)rects, count);
  static bool initial_frame = true;
  if (initial_frame) {
    SDL_ShowWindow(window);
    initial_frame = false;
  }
}

void ren_set_clip_rect(RenRect rect) {
  clip.left   = rect.x;
  clip.top    = rect.y;
  clip.right  = rect.x + rect.width;
  clip.bottom = rect.y + rect.height;
}

void ren_get_size(int *x, int *y) {
  surface = SDL_GetWindowSurface(window);
  assert(surface);
  *x = surface->w;
  *y = surface->h;
}


RenImage *ren_new_image(int width, int height) {
  assert(width > 0 && height > 0);
  RenImage *img = malloc(sizeof(RenImage) + width * height * sizeof(RenColor));
  check_alloc(img);
  img->pixels = (void *)(img + 1);
  img->width  = width;
  img->height = height;
  return img;
}

void ren_free_image(RenImage *image) {
  free(image);
}


static GlyphSet *load_glyphset(RenFont *font, int idx) {
  GlyphSet *set = check_alloc(calloc(1, sizeof(GlyphSet)));
  int width = 128, height = 128;

retry:
  set->image = ren_new_image(width, height);
  float s = stbtt_ScaleForMappingEmToPixels(&font->stbfont, 1)
           / stbtt_ScaleForPixelHeight(&font->stbfont, 1);
  int res = stbtt_BakeFontBitmap(
    font->data, 0, font->size * s,
    (void *)set->image->pixels,
    width, height, idx * 256, 256, set->glyphs);

  if (res < 0) {
    width  *= 2;
    height *= 2;
    ren_free_image(set->image);
    goto retry;
  }

  int ascent, descent, linegap;
  stbtt_GetFontVMetrics(&font->stbfont, &ascent, &descent, &linegap);
  float scale = stbtt_ScaleForMappingEmToPixels(&font->stbfont, font->size);
  int scaled_ascent = (int)(ascent * scale + 0.5f);

  for (int i = 0; i < 256; i++) {
    set->glyphs[i].yoff     += scaled_ascent;
    set->glyphs[i].xadvance  = floorf(set->glyphs[i].xadvance);
  }

  for (int i = width * height - 1; i >= 0; i--) {
    uint8_t a = *((uint8_t *)set->image->pixels + i);
    set->image->pixels[i] = (RenColor){ .r=255, .g=255, .b=255, .a=a };
  }

  return set;
}

static GlyphSet *get_glyphset(RenFont *font, int codepoint) {
  int idx = (codepoint >> 8) % MAX_GLYPHSET;
  if (!font->sets[idx]) font->sets[idx] = load_glyphset(font, idx);
  return font->sets[idx];
}

RenFont *ren_load_font(const char *filename, float size) {
  RenFont *font = check_alloc(calloc(1, sizeof(RenFont)));
  font->size = size;

  FILE *fp = fopen(filename, "rb");
  if (!fp) { free(font); return NULL; }

  fseek(fp, 0, SEEK_END);
  int buf_size = (int)ftell(fp);
  fseek(fp, 0, SEEK_SET);

  font->data = check_alloc(malloc(buf_size));
  int r = (int)fread(font->data, 1, buf_size, fp); (void)r;
  fclose(fp);

  if (!stbtt_InitFont(&font->stbfont, font->data, 0)) {
    free(font->data); free(font); return NULL;
  }

  int ascent, descent, linegap;
  stbtt_GetFontVMetrics(&font->stbfont, &ascent, &descent, &linegap);
  float scale = stbtt_ScaleForMappingEmToPixels(&font->stbfont, size);
  font->height = (int)((ascent - descent + linegap) * scale + 0.5f);

  /* Make tab/newline invisible */
  stbtt_bakedchar *g = get_glyphset(font, '\n')->glyphs;
  g['\t'].x1 = g['\t'].x0;
  g['\n'].x1 = g['\n'].x0;

  return font;
}

void ren_free_font(RenFont *font) {
  for (int i = 0; i < MAX_GLYPHSET; i++) {
    GlyphSet *set = font->sets[i];
    if (set) { ren_free_image(set->image); free(set); }
  }
  free(font->data);
  free(font);
}

void ren_set_font_tab_width(RenFont *font, int n) {
  get_glyphset(font, '\t')->glyphs['\t'].xadvance = (float)n;
}

int ren_get_font_tab_width(RenFont *font) {
  return (int)get_glyphset(font, '\t')->glyphs['\t'].xadvance;
}

int ren_get_font_width(RenFont *font, const char *text) {
  int x = 0;
  unsigned cp;
  for (const char *p = text; *p; ) {
    p = utf8_to_codepoint(p, &cp);
    x += (int)get_glyphset(font, cp)->glyphs[cp & 0xff].xadvance;
  }
  return x;
}

int ren_get_font_height(RenFont *font) {
  return font->height;
}

float ren_get_font_size(RenFont *font) {
  return font->size;
}


static inline RenColor blend_pixel(RenColor dst, RenColor src) {
  int ia = 0xff - src.a;
  dst.r = (uint8_t)(((src.r * src.a) + (dst.r * ia)) >> 8);
  dst.g = (uint8_t)(((src.g * src.a) + (dst.g * ia)) >> 8);
  dst.b = (uint8_t)(((src.b * src.a) + (dst.b * ia)) >> 8);
  return dst;
}

static inline RenColor blend_pixel2(RenColor dst, RenColor src, RenColor color) {
  src.a = (uint8_t)((src.a * color.a) >> 8);
  int ia = 0xff - src.a;
  dst.r = (uint8_t)(((src.r * color.r * src.a) >> 16) + ((dst.r * ia) >> 8));
  dst.g = (uint8_t)(((src.g * color.g * src.a) >> 16) + ((dst.g * ia) >> 8));
  dst.b = (uint8_t)(((src.b * color.b * src.a) >> 16) + ((dst.b * ia) >> 8));
  return dst;
}

void ren_draw_rect(RenRect rect, RenColor color) {
  if (color.a == 0) return;

  int x1 = rect.x < clip.left   ? clip.left   : rect.x;
  int y1 = rect.y < clip.top    ? clip.top    : rect.y;
  int x2 = rect.x + rect.width;
  int y2 = rect.y + rect.height;
  x2 = x2 > clip.right  ? clip.right  : x2;
  y2 = y2 > clip.bottom ? clip.bottom : y2;
  if (x1 >= x2 || y1 >= y2) return;
  RenColor *d = (RenColor *)surface->pixels + x1 + y1 * surface->w;
  int dr = surface->w - (x2 - x1);

  if (color.a == 0xff) {
    for (int j = y1; j < y2; j++) {
      for (int i = x1; i < x2; i++) { *d++ = color; }
      d += dr;
    }
  } else {
    for (int j = y1; j < y2; j++) {
      for (int i = x1; i < x2; i++) { *d = blend_pixel(*d, color); d++; }
      d += dr;
    }
  }
}

void ren_draw_image(RenImage *image, RenRect *sub, int x, int y, RenColor color) {
  if (color.a == 0) return;
  int n;
  if ((n = clip.left - x) > 0) { sub->width  -= n; sub->x += n; x += n; }
  if ((n = clip.top  - y) > 0) { sub->height -= n; sub->y += n; y += n; }
  if ((n = x + sub->width  - clip.right)  > 0) { sub->width  -= n; }
  if ((n = y + sub->height - clip.bottom) > 0) { sub->height -= n; }
  if (sub->width <= 0 || sub->height <= 0) return;

  RenColor *s = image->pixels + sub->x + sub->y * image->width;
  RenColor *d = (RenColor *)surface->pixels + x + y * surface->w;
  int sr = image->width  - sub->width;
  int dr = surface->w    - sub->width;

  for (int j = 0; j < sub->height; j++) {
    for (int i = 0; i < sub->width; i++) {
      *d = blend_pixel2(*d, *s, color);
      d++; s++;
    }
    d += dr; s += sr;
  }
}

int ren_draw_text(RenFont *font, const char *text, int x, int y, RenColor color) {
  unsigned cp;
  for (const char *p = text; *p; ) {
    p = utf8_to_codepoint(p, &cp);
    GlyphSet *set = get_glyphset(font, cp);
    stbtt_bakedchar *g = &set->glyphs[cp & 0xff];
    RenRect rect = { g->x0, g->y0, g->x1 - g->x0, g->y1 - g->y0 };
    ren_draw_image(set->image, &rect, x + (int)g->xoff, y + (int)g->yoff, color);
    x += (int)g->xadvance;
  }
  return x;
}