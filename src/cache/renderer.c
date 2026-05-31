#include "cache_engine.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#define GLYPH_TABLE_DEFAULT 4096  

typedef struct GlyphSlot {
  CdinHash   key;        
  GlyphEntry glyph;     
  uint8_t   *bitmap;    
  
  struct GlyphSlot *lru_prev;
  struct GlyphSlot *lru_next;
  
  CdinHash   font_hash;
} GlyphSlot;

struct CdinRenderCache {
  GlyphSlot  *slots;
  size_t      capacity;
  size_t      count;
  size_t      max_entries;
  
  GlyphSlot   lru_head;
  GlyphSlot   lru_tail;
};

static void glru_remove(GlyphSlot *s) {
  if (!s->lru_prev) return;
  s->lru_prev->lru_next = s->lru_next;
  s->lru_next->lru_prev = s->lru_prev;
  s->lru_prev = s->lru_next = NULL;
}

static void glru_push_front(CdinRenderCache *rc, GlyphSlot *s) {
  s->lru_next = rc->lru_head.lru_next;
  s->lru_prev = &rc->lru_head;
  rc->lru_head.lru_next->lru_prev = s;
  rc->lru_head.lru_next = s;
}

static void glyph_evict_slot(CdinRenderCache *rc, GlyphSlot *s) {
  glru_remove(s);
  free(s->bitmap);
  s->bitmap = NULL;
  s->key    = CDIN_HASH_NONE;
  rc->count--;
}

static void glyph_evict_lru(CdinRenderCache *rc) {
  GlyphSlot *victim = rc->lru_tail.lru_prev;
  if (victim == &rc->lru_head) return;
  glyph_evict_slot(rc, victim);
}

static GlyphSlot *glyph_find(CdinRenderCache *rc, CdinHash key) {
  size_t idx = (size_t)(key & (CdinHash)(rc->capacity - 1));
  for (size_t p = 0; p < rc->capacity; p++) {
    GlyphSlot *s = &rc->slots[(idx + p) & (rc->capacity - 1)];
    if (s->key == CDIN_HASH_NONE || s->key == key) return s;
  }
  return NULL;
}

CdinHash render_glyph_key(const char *font_path, float size, uint32_t codepoint) {
  CdinHash h = cache_hash_str(font_path);
  CdinHash hs = cache_hash_bytes(&size, sizeof(size));
  CdinHash hc = cache_hash_bytes(&codepoint, sizeof(codepoint));
  return cache_hash_combine(h, cache_hash_combine(hs, hc));
}

CdinRenderCache *render_cache_create(size_t max_glyphs) {
  CdinRenderCache *rc = calloc(1, sizeof(CdinRenderCache));
  if (!rc) return NULL;

  rc->max_entries = max_glyphs ? max_glyphs : GLYPH_TABLE_DEFAULT;
  rc->capacity    = GLYPH_TABLE_DEFAULT;
  while (rc->capacity < rc->max_entries * 2) rc->capacity *= 2;

  rc->slots = calloc(rc->capacity, sizeof(GlyphSlot));
  if (!rc->slots) { free(rc); return NULL; }

  
  for (size_t i = 0; i < rc->capacity; i++)
    rc->slots[i].key = CDIN_HASH_NONE;

  rc->lru_head.lru_next = &rc->lru_tail;
  rc->lru_tail.lru_prev = &rc->lru_head;
  return rc;
}

void render_cache_destroy(CdinRenderCache *rc) {
  if (!rc) return;
  for (size_t i = 0; i < rc->capacity; i++) {
    if (rc->slots[i].key != CDIN_HASH_NONE) free(rc->slots[i].bitmap);
  }
  free(rc->slots);
  free(rc);
}

const GlyphEntry *render_cache_get(CdinRenderCache *rc, CdinHash key) {
  if (!rc || key == CDIN_HASH_NONE) return NULL;

  GlyphSlot *s = glyph_find(rc, key);
  if (!s || s->key != key) return NULL;

  glru_remove(s);
  glru_push_front(rc, s);
  return &s->glyph;
}

void render_cache_put(CdinRenderCache *rc, CdinHash key,
                      int w, int h, int xoff, int yoff, int advance,
                      const uint8_t *bitmap) {
  if (!rc || key == CDIN_HASH_NONE) return;

  
  while (rc->count >= rc->max_entries) glyph_evict_lru(rc);

  GlyphSlot *s = glyph_find(rc, key);
  if (!s) return;

  if (s->key == key) {
    
    glru_remove(s);
    glru_push_front(rc, s);
    return;
  }

  
  size_t bsize = (size_t)w * (size_t)h;
  uint8_t *bm  = malloc(bsize);
  if (!bm) return;
  if (bitmap && bsize > 0) memcpy(bm, bitmap, bsize);

  s->key         = key;
  s->bitmap      = bm;
  s->glyph.width   = w;
  s->glyph.height  = h;
  s->glyph.xoff    = xoff;
  s->glyph.yoff    = yoff;
  s->glyph.advance = advance;
  s->glyph.bitmap  = bm;

  glru_push_front(rc, s);
  rc->count++;
}

void render_cache_evict_font(CdinRenderCache *rc, const char *font_path) {
  if (!rc || !font_path) return;
  CdinHash fh = cache_hash_str(font_path);

  for (size_t i = 0; i < rc->capacity; i++) {
    GlyphSlot *s = &rc->slots[i];
    if (s->key == CDIN_HASH_NONE) continue;
    if (s->font_hash == fh) glyph_evict_slot(rc, s);
  }
}