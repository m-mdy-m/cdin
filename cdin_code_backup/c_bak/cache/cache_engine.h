#ifndef CACHE_ENGINE_H
#define CACHE_ENGINE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <time.h>
typedef uint64_t CdinHash;

#define CDIN_HASH_NONE  ((CdinHash)0)
CdinHash cache_hash_bytes(const void *data, size_t len);
CdinHash cache_hash_str(const char *str);
CdinHash cache_hash_combine(CdinHash a, CdinHash b);
CdinHash cache_hash_file_meta(const char *path);
CdinHash cache_hash_file_content(const char *path);
void cache_hash_to_hex(CdinHash h, char *buf);
typedef enum {
  CDIN_OBJ_BLOB   = 1,   
  CDIN_OBJ_TREE   = 2,   
  CDIN_OBJ_GLYPH  = 3,   
} CdinObjType;

typedef struct {
  CdinObjType type;
  size_t      data_size;   
  CdinHash    hash;        
  time_t      created_at;
} CdinObjHeader;

typedef struct {
  const CdinObjHeader *header;
  const void          *data;    
} CdinObj;

typedef struct CdinStore CdinStore;
CdinStore *store_create(size_t max_bytes, size_t max_entries);
void       store_destroy(CdinStore *s);

bool store_put(CdinStore *s, CdinHash h, CdinObjType type,
               const void *data, size_t size);

CdinObj store_get(CdinStore *s, CdinHash h);
void store_evict(CdinStore *s, CdinHash h);
void store_evict_prefix(CdinStore *s, const char *path_prefix);
typedef struct {
  size_t entries;
  size_t bytes_used;
  size_t bytes_limit;
  size_t hits;
  size_t misses;
  size_t evictions;
} CdinStoreStats;

CdinStoreStats store_stats(const CdinStore *s);
typedef struct {
  char   *text;        
  size_t  text_len;
  CdinHash content_hash;
  time_t  mtime;
} BlobEntry;

typedef struct CdinBlobCache CdinBlobCache;

CdinBlobCache *blob_cache_create(size_t max_bytes);
void           blob_cache_destroy(CdinBlobCache *bc);
const BlobEntry *blob_cache_get(CdinBlobCache *bc, const char *path);
void blob_cache_invalidate(CdinBlobCache *bc, const char *path);
bool blob_cache_is_stale(CdinBlobCache *bc, const char *path);

typedef struct {
  char     name[256];   
  char     path[1024];  
  bool     is_dir;
  CdinHash hash;        
  time_t   mtime;
  size_t   size;        
} TreeEntry;

typedef struct {
  char        root[1024];
  TreeEntry  *entries;
  size_t      count;
  CdinHash    tree_hash;  
  time_t      scanned_at;
} TreeSnapshot;

typedef struct CdinTreeCache CdinTreeCache;

CdinTreeCache   *tree_cache_create(size_t max_entries);
void             tree_cache_destroy(CdinTreeCache *tc);
const TreeSnapshot *tree_cache_get(CdinTreeCache *tc, const char *root);
void tree_cache_put(CdinTreeCache *tc, TreeSnapshot *snap);
bool tree_cache_is_valid(CdinTreeCache *tc, const char *root);
void tree_cache_invalidate(CdinTreeCache *tc, const char *root);
CdinHash tree_hash_entries(const TreeEntry *entries, size_t count);
typedef struct {
  int      width;
  int      height;
  int      xoff;      
  int      yoff;      
  int      advance;   
  uint8_t *bitmap;    
} GlyphEntry;
typedef struct CdinRenderCache CdinRenderCache;
CdinRenderCache *render_cache_create(size_t max_glyphs);
void             render_cache_destroy(CdinRenderCache *rc);
CdinHash render_glyph_key(const char *font_path, float size, uint32_t codepoint);


const GlyphEntry *render_cache_get(CdinRenderCache *rc, CdinHash key);


void render_cache_put(CdinRenderCache *rc, CdinHash key,
                      int w, int h, int xoff, int yoff, int advance,
                      const uint8_t *bitmap);

void render_cache_evict_font(CdinRenderCache *rc, const char *font_path);
typedef struct {
  CdinBlobCache   *blob;
  CdinTreeCache   *tree;
  CdinRenderCache *render;
  CdinStore       *store;   
} CdinCacheEngine;
CdinCacheEngine *cache_engine_create(size_t blob_mb,
                                     size_t tree_max,
                                     size_t glyph_max);
void cache_engine_destroy(CdinCacheEngine *e);
void cache_engine_dump_stats(const CdinCacheEngine *e);

#endif 