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
#include "../core/logger.h"

/* Glyphs are baked in blocks of 256 codepoints ("pages"), keyed by the
   codepoint's high bits (cp >> 8) — one page per 0x100 codepoint range,
   e.g. page 0x1F3 covers U+1F300..U+1F3FF (misc symbols/pictographs).
   Pages are looked up in a small open-addressing hash table sized for the
   whole Unicode range (cp up to 0x10FFFF => up to ~4352 possible pages),
   allocated lazily so this stays cheap for BMP-only text. This replaces a
   fixed 256-bucket table indexed by `(cp >> 8) % 256`, which wrapped
   around and silently collided unrelated blocks together once codepoints
   went past the BMP (e.g. an emoji at U+1FA87 landed in the same bucket
   as CJK Compatibility Ideographs at U+FA00-FAFF and could draw the
   wrong glyph instead of just being missing). */
#define GLYPHSET_TABLE_SIZE 8192  /* power of 2; open-addressed, ~65% max load */

struct RenImage {
  RenColor *pixels;
  int width, height;
};

typedef struct {
  RenImage *image;
  stbtt_bakedchar glyphs[256];
  int page;      /* cp >> 8 this set was baked for; -1 = empty slot */
  bool has_bitmap;
} GlyphSet;

#define MAX_FALLBACK_FONTS 8

struct RenFont {
  void *data;
  stbtt_fontinfo stbfont;
  GlyphSet **table;   /* GLYPHSET_TABLE_SIZE slots, lazily populated */
  float size;
  int height;
  RenFont *fallback[MAX_FALLBACK_FONTS];
  int fallback_count;
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
  /* Hardened decoder: never over-reads, rejects overlong/truncated
     sequences and surrogates, returns U+FFFD on error. */
  unsigned char c = (unsigned char)*p;
  if (c < 0x80) { *dst = c; return p + 1; }
  unsigned res = 0, n = 0, lo = 0x80, hi = 0xBF;
  if ((c & 0xE0) == 0xC0)      { res = c & 0x1F; n = 1; lo = (c == 0xC0 || c == 0xC1) ? 0x100 : 0x80; }
  else if ((c & 0xF0) == 0xE0) { res = c & 0x0F; n = 2; }
  else if ((c & 0xF8) == 0xF0) { res = c & 0x07; n = 3; }
  else { *dst = 0xFFFD; return p + 1; }
  for (unsigned i = 1; i <= n; i++) {
    unsigned char cc = (unsigned char)p[i];
    if (i == 1 && n > 1) {
      if (c == 0xE0) lo = 0xA0;
      else if (c == 0xED) hi = 0x9F;
      else if (c == 0xF0) lo = 0x90;
      else if (c == 0xF4) hi = 0x8F;
    }
    if (cc < lo || cc > hi || p[i] == '\0') { *dst = 0xFFFD; return p + 1; }
    lo = 0x80; hi = 0xBF;
    res = (res << 6) | (cc & 0x3F);
  }
  if (res > 0x10FFFF || (res >= 0xD800 && res <= 0xDFFF)) res = 0xFFFD;
  *dst = res;
  return p + n + 1;
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
  surface = SDL_GetWindowSurface(window);
  assert(surface);
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


static GlyphSet *load_glyphset(RenFont *font, int page) {
  GlyphSet *set = check_alloc(calloc(1, sizeof(GlyphSet)));
  set->page = page;
  int width = 128, height = 128;

retry:
  set->image = ren_new_image(width, height);
  float s = stbtt_ScaleForMappingEmToPixels(&font->stbfont, 1)
           / stbtt_ScaleForPixelHeight(&font->stbfont, 1);
  int res = stbtt_BakeFontBitmap(
    font->data, 0, font->size * s,
    (void *)set->image->pixels,
    width, height, page * 256, 256, set->glyphs);

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
    /* A codepoint this font truly has no outline for bakes to a zero-area
       glyph (unless it's whitespace, which is legitimately zero-area).
       Recording that here lets callers fall back to another font instead
       of silently drawing nothing. */
    stbtt_bakedchar *g = &set->glyphs[i];
    bool empty_box = (g->x1 <= g->x0 || g->y1 <= g->y0);
    int cp = page * 256 + i;
    bool expected_blank = (cp == ' ' || cp == '\t' || cp == '\n' || cp == '\r');
    if (!empty_box || expected_blank) set->has_bitmap = true;
  }

  for (int i = width * height - 1; i >= 0; i--) {
    uint8_t a = *((uint8_t *)set->image->pixels + i);
    set->image->pixels[i] = (RenColor){ .r=255, .g=255, .b=255, .a=a };
  }

  return set;
}

static GlyphSet **glyphset_slot(RenFont *font, int page) {
  if (!font->table) {
    font->table = check_alloc(calloc(GLYPHSET_TABLE_SIZE, sizeof(GlyphSet *)));
  }
  unsigned h = ((unsigned)page * 2654435761u) & (GLYPHSET_TABLE_SIZE - 1);
  for (int probes = 0; probes < GLYPHSET_TABLE_SIZE; probes++) {
    GlyphSet **slot = &font->table[h];
    if (*slot == NULL || (*slot)->page == page) return slot;
    h = (h + 1) & (GLYPHSET_TABLE_SIZE - 1);
  }
  static GlyphSet *scratch;
  return &scratch;
}

static GlyphSet *get_glyphset(RenFont *font, int codepoint) {
  if (codepoint < 0 || codepoint > 0x10FFFF) codepoint = 0xFFFD;
  int page = codepoint >> 8;
  GlyphSet **slot = glyphset_slot(font, page);
  if (!*slot) *slot = load_glyphset(font, page);
  return *slot;
}

static bool font_has_glyph(RenFont *font, int codepoint) {
  GlyphSet *set = get_glyphset(font, codepoint);
  return set && set->has_bitmap;
}

static RenFont *resolve_font_for(RenFont *font, int codepoint) {
  if (font_has_glyph(font, codepoint)) return font;
  for (int i = 0; i < font->fallback_count; i++) {
    if (font_has_glyph(font->fallback[i], codepoint)) return font->fallback[i];
  }
  return font;
}

void ren_font_add_fallback(RenFont *font, RenFont *fallback) {
  if (!font || !fallback || font == fallback) return;
  if (font->fallback_count >= MAX_FALLBACK_FONTS) {
    log_warn("renderer: fallback chain full (%d), ignoring additional fallback font",
             MAX_FALLBACK_FONTS);
    return;
  }
  font->fallback[font->fallback_count++] = fallback;
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
  if (font->table) {
    for (int i = 0; i < GLYPHSET_TABLE_SIZE; i++) {
      GlyphSet *set = font->table[i];
      if (set) { ren_free_image(set->image); free(set); }
    }
    free(font->table);
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
  if (!font || !text) return 0;
  int x = 0;
  unsigned cp;
  /* Cap measured length so a multi-MB line cannot stall a frame. */
  int bytes = 0;
  for (const char *p = text; *p && bytes < 65536; ) {
    p = utf8_to_codepoint(p, &cp);
    bytes = (int)(p - text);
    RenFont *use = font->fallback_count ? resolve_font_for(font, (int)cp) : font;
    GlyphSet *set = get_glyphset(use, (int)cp);
    if (!set) break;
    x += (int)set->glyphs[cp & 0xff].xadvance;
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
  if (!font || !text || color.a == 0) return x;
  unsigned cp;
  int drawn = 0;
  /* Baseline offset so a fallback font (which may have different metrics/
     ascent at the same pixel size) still sits on the same text baseline
     as the primary font, instead of glyphs jumping up/down mid-line. */
  int base_ascent = ren_get_font_height(font);
  for (const char *p = text; *p && drawn < 4096; ) {
    p = utf8_to_codepoint(p, &cp);
    RenFont *use = font->fallback_count ? resolve_font_for(font, (int)cp) : font;
    GlyphSet *set = get_glyphset(use, (int)cp);
    if (!set) break;
    stbtt_bakedchar *g = &set->glyphs[cp & 0xff];
    int yoff = y;
    if (use != font) yoff += base_ascent - ren_get_font_height(use);
    /* Skip zero-size/dirty glyphs (e.g. missing coverage) safely. */
    if (g->x1 > g->x0 && g->y1 > g->y0) {
      RenRect rect = { g->x0, g->y0, g->x1 - g->x0, g->y1 - g->y0 };
      ren_draw_image(set->image, &rect, x + (int)g->xoff, yoff + (int)g->yoff, color);
    }
    x += (int)g->xadvance;
    drawn++;
  }
  return x;
}