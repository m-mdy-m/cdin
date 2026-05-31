#include "cache_engine.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#include <time.h>

#define FNV_OFFSET  14695981039346656037ULL
#define FNV_PRIME   1099511628211ULL

CdinHash cache_hash_bytes(const void *data, size_t len) {
  const uint8_t *p = (const uint8_t *)data;
  CdinHash h = FNV_OFFSET;
  for (size_t i = 0; i < len; i++) {
    h ^= (CdinHash)p[i];
    h *= FNV_PRIME;
  }
  return h ? h : 1; 
}

CdinHash cache_hash_str(const char *str) {
  return cache_hash_bytes(str, strlen(str));
}

CdinHash cache_hash_combine(CdinHash a, CdinHash b) {
  
  a ^= b + 0x9e3779b97f4a7c15ULL + (a << 6) + (a >> 2);
  return a ? a : 1;
}

CdinHash cache_hash_file_meta(const char *path) {
  struct stat st;
  if (stat(path, &st) != 0) return CDIN_HASH_NONE;

  
  CdinHash h = cache_hash_str(path);
  CdinHash hm = cache_hash_bytes(&st.st_mtime, sizeof(st.st_mtime));
  CdinHash hs = cache_hash_bytes(&st.st_size,  sizeof(st.st_size));
  return cache_hash_combine(h, cache_hash_combine(hm, hs));
}

CdinHash cache_hash_file_content(const char *path) {
  FILE *fp = fopen(path, "rb");
  if (!fp) return CDIN_HASH_NONE;

  CdinHash h = FNV_OFFSET;
  uint8_t buf[4096];
  size_t n;
  while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
    for (size_t i = 0; i < n; i++) {
      h ^= (CdinHash)buf[i];
      h *= FNV_PRIME;
    }
  }
  fclose(fp);
  return h ? h : 1;
}

void cache_hash_to_hex(CdinHash h, char *buf) {
  
  static const char hex[] = "0123456789abcdef";
  for (int i = 15; i >= 0; i--) {
    buf[i] = hex[h & 0xF];
    h >>= 4;
  }
  buf[16] = '\0';
}

#define STORE_INITIAL_BUCKETS 1024  
#define STORE_LOAD_FACTOR     0.7f
#define STORE_DEFAULT_BYTES   (64ULL * 1024 * 1024)  
#define STORE_DEFAULT_ENTRIES 8192


typedef struct StoreSlot {
  CdinHash       key;      
  CdinObjHeader *header;   
  
  struct StoreSlot *lru_prev;
  struct StoreSlot *lru_next;
} StoreSlot;

struct CdinStore {
  StoreSlot    *slots;
  size_t        capacity;   
  size_t        count;      
  size_t        bytes_used;
  size_t        bytes_limit;
  size_t        max_entries;
  
  StoreSlot     lru_head;  
  StoreSlot     lru_tail;  
  
  size_t        hits;
  size_t        misses;
  size_t        evictions;
};

static void lru_remove(StoreSlot *s) {
  s->lru_prev->lru_next = s->lru_next;
  s->lru_next->lru_prev = s->lru_prev;
  s->lru_prev = s->lru_next = NULL;
}

static void lru_push_front(CdinStore *st, StoreSlot *s) {
  s->lru_next = st->lru_head.lru_next;
  s->lru_prev = &st->lru_head;
  st->lru_head.lru_next->lru_prev = s;
  st->lru_head.lru_next = s;
}

static void lru_promote(CdinStore *st, StoreSlot *s) {
  lru_remove(s);
  lru_push_front(st, s);
}
static size_t slot_index(const CdinStore *st, CdinHash h) {
  return (size_t)(h & (CdinHash)(st->capacity - 1));
}


static StoreSlot *slot_find(CdinStore *st, CdinHash h) {
  size_t idx = slot_index(st, h);
  for (size_t probe = 0; probe < st->capacity; probe++) {
    StoreSlot *s = &st->slots[(idx + probe) & (st->capacity - 1)];
    if (s->key == CDIN_HASH_NONE || s->key == h) return s;
  }
  return NULL; 
}

static void store_evict_lru(CdinStore *st) {
  
  StoreSlot *victim = st->lru_tail.lru_prev;
  if (victim == &st->lru_head) return; 

  lru_remove(victim);
  st->bytes_used -= sizeof(CdinObjHeader) + victim->header->data_size;
  free(victim->header);
  victim->header = NULL;
  victim->key    = CDIN_HASH_NONE;
  st->count--;
  st->evictions++;
}

CdinStore *store_create(size_t max_bytes, size_t max_entries) {
  CdinStore *st = calloc(1, sizeof(CdinStore));
  if (!st) return NULL;

  st->capacity    = STORE_INITIAL_BUCKETS;
  st->bytes_limit = max_bytes   ? max_bytes   : STORE_DEFAULT_BYTES;
  st->max_entries = max_entries ? max_entries : STORE_DEFAULT_ENTRIES;

  st->slots = calloc(st->capacity, sizeof(StoreSlot));
  if (!st->slots) { free(st); return NULL; }

  
  st->lru_head.lru_next = &st->lru_tail;
  st->lru_tail.lru_prev = &st->lru_head;

  return st;
}

void store_destroy(CdinStore *st) {
  if (!st) return;
  for (size_t i = 0; i < st->capacity; i++) {
    if (st->slots[i].key != CDIN_HASH_NONE)
      free(st->slots[i].header);
  }
  free(st->slots);
  free(st);
}

bool store_put(CdinStore *st, CdinHash h, CdinObjType type,
               const void *data, size_t size) {
  if (!st || h == CDIN_HASH_NONE) return false;

  
  while (st->count >= st->max_entries ||
         st->bytes_used + sizeof(CdinObjHeader) + size > st->bytes_limit) {
    if (st->count == 0) return false; 
    store_evict_lru(st);
  }

  
  StoreSlot *s = slot_find(st, h);
  if (!s) return false;

  if (s->key == h) {
    
    lru_promote(st, s);
    return true;
  }

  
  size_t total = sizeof(CdinObjHeader) + size;
  CdinObjHeader *hdr = malloc(total);
  if (!hdr) return false;

  hdr->type      = type;
  hdr->data_size = size;
  hdr->hash      = h;
  hdr->created_at = time(NULL);
  if (size > 0 && data) memcpy(hdr + 1, data, size);

  s->key    = h;
  s->header = hdr;
  lru_push_front(st, s);

  st->count++;
  st->bytes_used += total;
  return true;
}

CdinObj store_get(CdinStore *st, CdinHash h) {
  CdinObj result = { NULL, NULL };
  if (!st) return result;
  if (h == CDIN_HASH_NONE) { st->misses++; return result; }

  StoreSlot *s = slot_find(st, h);
  if (!s || s->key != h) { st->misses++; return result; }

  lru_promote(st, s);
  st->hits++;
  result.header = s->header;
  result.data   = (s->header->data_size > 0) ? (void *)(s->header + 1) : NULL;
  return result;
}

void store_evict(CdinStore *st, CdinHash h) {
  if (!st || h == CDIN_HASH_NONE) return;
  StoreSlot *s = slot_find(st, h);
  if (!s || s->key != h) return;

  lru_remove(s);
  st->bytes_used -= sizeof(CdinObjHeader) + s->header->data_size;
  free(s->header);
  s->header = NULL;
  s->key    = CDIN_HASH_NONE;
  st->count--;
  st->evictions++;
}

void store_evict_prefix(CdinStore *st, const char *path_prefix) {
  if (!st || !path_prefix) return;

  CdinHash prefix_h = cache_hash_str(path_prefix);

  for (size_t i = 0; i < st->capacity; i++) {
    StoreSlot *s = &st->slots[i];
    if (s->key == CDIN_HASH_NONE) continue;
    if (s->key == prefix_h) {
      lru_remove(s);
      st->bytes_used -= sizeof(CdinObjHeader) + s->header->data_size;
      free(s->header);
      s->header = NULL;
      s->key    = CDIN_HASH_NONE;
      st->count--;
      st->evictions++;
    }
  }
}

CdinStoreStats store_stats(const CdinStore *st) {
  CdinStoreStats s = {0};
  if (!st) return s;
  s.entries    = st->count;
  s.bytes_used = st->bytes_used;
  s.bytes_limit= st->bytes_limit;
  s.hits       = st->hits;
  s.misses     = st->misses;
  s.evictions  = st->evictions;
  return s;
}

CdinCacheEngine *cache_engine_create(size_t blob_mb,
                                     size_t tree_max,
                                     size_t glyph_max) {
  CdinCacheEngine *e = calloc(1, sizeof(CdinCacheEngine));
  if (!e) return NULL;

  size_t blob_bytes = blob_mb ? blob_mb * 1024 * 1024 : 32ULL * 1024 * 1024;

  e->store  = store_create(blob_bytes + 8 * 1024 * 1024, 0);
  e->blob   = blob_cache_create(blob_bytes);
  e->tree   = tree_cache_create(tree_max ? tree_max : 2048);
  e->render = render_cache_create(glyph_max ? glyph_max : 4096);

  if (!e->store || !e->blob || !e->tree || !e->render) {
    cache_engine_destroy(e);
    return NULL;
  }
  return e;
}

void cache_engine_destroy(CdinCacheEngine *e) {
  if (!e) return;
  if (e->blob)   blob_cache_destroy(e->blob);
  if (e->tree)   tree_cache_destroy(e->tree);
  if (e->render) render_cache_destroy(e->render);
  if (e->store)  store_destroy(e->store);
  free(e);
}

void cache_engine_dump_stats(const CdinCacheEngine *e) {
  if (!e) return;
  CdinStoreStats ss = store_stats(e->store);
  fprintf(stderr,
    "[cache] store: %zu entries, %zu KB used / %zu KB limit, "
    "%zu hits, %zu misses, %zu evictions\n",
    ss.entries,
    ss.bytes_used  / 1024,
    ss.bytes_limit / 1024,
    ss.hits, ss.misses, ss.evictions);
}