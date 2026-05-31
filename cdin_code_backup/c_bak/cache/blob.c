#include "cache_engine.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#define BLOB_TABLE_SIZE 512   

typedef struct BlobSlot {
  char      path[1024];
  CdinHash  meta_hash;   
  BlobEntry entry;       
} BlobSlot;

struct CdinBlobCache {
  BlobSlot *slots;      
  size_t    capacity;
  size_t    count;
  size_t    bytes_used;
  size_t    bytes_limit;
};
static size_t blob_index(const CdinBlobCache *bc, const char *path) {
  CdinHash h = cache_hash_str(path);
  return (size_t)(h & (CdinHash)(bc->capacity - 1));
}

static BlobSlot *blob_find(CdinBlobCache *bc, const char *path) {
  size_t idx = blob_index(bc, path);
  for (size_t p = 0; p < bc->capacity; p++) {
    BlobSlot *s = &bc->slots[(idx + p) & (bc->capacity - 1)];
    if (s->path[0] == '\0') return s;          
    if (strcmp(s->path, path) == 0) return s;  
  }
  return NULL;
}

static bool blob_load_file(BlobSlot *s, const char *path) {
  FILE *fp = fopen(path, "rb");
  if (!fp) return false;

  fseek(fp, 0, SEEK_END);
  long sz = ftell(fp);
  fseek(fp, 0, SEEK_SET);

  if (sz < 0) { fclose(fp); return false; }

  char *buf = malloc((size_t)sz + 1);
  if (!buf) { fclose(fp); return false; }

  size_t r = fread(buf, 1, (size_t)sz, fp);
  fclose(fp);
  buf[r] = '\0';

  
  free(s->entry.text);

  s->entry.text         = buf;
  s->entry.text_len     = r;
  s->entry.content_hash = cache_hash_bytes(buf, r);

  struct stat st;
  if (stat(path, &st) == 0) s->entry.mtime = st.st_mtime;

  return true;
}

CdinBlobCache *blob_cache_create(size_t max_bytes) {
  CdinBlobCache *bc = calloc(1, sizeof(CdinBlobCache));
  if (!bc) return NULL;

  bc->capacity    = BLOB_TABLE_SIZE;
  bc->bytes_limit = max_bytes ? max_bytes : 32ULL * 1024 * 1024;
  bc->slots       = calloc(bc->capacity, sizeof(BlobSlot));
  if (!bc->slots) { free(bc); return NULL; }

  return bc;
}

void blob_cache_destroy(CdinBlobCache *bc) {
  if (!bc) return;
  for (size_t i = 0; i < bc->capacity; i++) {
    if (bc->slots[i].path[0]) free(bc->slots[i].entry.text);
  }
  free(bc->slots);
  free(bc);
}

const BlobEntry *blob_cache_get(CdinBlobCache *bc, const char *path) {
  if (!bc || !path) return NULL;

  BlobSlot *s = blob_find(bc, path);
  if (!s) return NULL;

  CdinHash meta = cache_hash_file_meta(path);
  if (meta == CDIN_HASH_NONE) return NULL; 

  if (s->path[0] != '\0' && s->meta_hash == meta) {
    
    return &s->entry;
  }

  
  if (s->path[0] == '\0') {
    strncpy(s->path, path, sizeof(s->path) - 1);
    s->path[sizeof(s->path) - 1] = '\0';
    bc->count++;
  } else {
    
    bc->bytes_used -= s->entry.text_len;
  }

  if (!blob_load_file(s, path)) {
    s->path[0] = '\0';
    bc->count--;
    return NULL;
  }

  s->meta_hash = meta;
  bc->bytes_used += s->entry.text_len;
  return &s->entry;
}

void blob_cache_invalidate(CdinBlobCache *bc, const char *path) {
  if (!bc || !path) return;
  BlobSlot *s = blob_find(bc, path);
  if (!s || s->path[0] == '\0') return;

  bc->bytes_used -= s->entry.text_len;
  free(s->entry.text);
  memset(s, 0, sizeof(*s));
  bc->count--;
}

bool blob_cache_is_stale(CdinBlobCache *bc, const char *path) {
  if (!bc || !path) return true;
  BlobSlot *s = blob_find(bc, path);
  if (!s || s->path[0] == '\0') return true;

  CdinHash meta = cache_hash_file_meta(path);
  return meta == CDIN_HASH_NONE || s->meta_hash != meta;
}