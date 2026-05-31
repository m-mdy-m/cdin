#include "cache_engine.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#define TREE_TABLE_SIZE 256

typedef struct TreeSlot {
  char          root[1024];
  CdinHash      root_meta_hash;  
  TreeSnapshot *snap;
} TreeSlot;

struct CdinTreeCache {
  TreeSlot *slots;
  size_t    capacity;
  size_t    count;
  size_t    max_entries;
};

static size_t tree_index(const CdinTreeCache *tc, const char *root) {
  CdinHash h = cache_hash_str(root);
  return (size_t)(h & (CdinHash)(tc->capacity - 1));
}

static TreeSlot *tree_find(CdinTreeCache *tc, const char *root) {
  size_t idx = tree_index(tc, root);
  for (size_t p = 0; p < tc->capacity; p++) {
    TreeSlot *s = &tc->slots[(idx + p) & (tc->capacity - 1)];
    if (s->root[0] == '\0') return s;
    if (strcmp(s->root, root) == 0) return s;
  }
  return NULL;
}

static CdinHash dir_meta_hash(const char *path) {
  struct stat st;
  if (stat(path, &st) != 0) return CDIN_HASH_NONE;
  CdinHash hp = cache_hash_str(path);
  CdinHash hm = cache_hash_bytes(&st.st_mtime, sizeof(st.st_mtime));
  return cache_hash_combine(hp, hm);
}

static void snapshot_free(TreeSnapshot *snap) {
  if (!snap) return;
  free(snap->entries);
  free(snap);
}

static int entry_cmp(const void *a, const void *b) {
  return strcmp(((const TreeEntry *)a)->name, ((const TreeEntry *)b)->name);
}

CdinHash tree_hash_entries(const TreeEntry *entries, size_t count) {
  if (!entries || count == 0) return cache_hash_str("empty-tree");

  
  TreeEntry *sorted = malloc(count * sizeof(TreeEntry));
  if (!sorted) return CDIN_HASH_NONE;
  memcpy(sorted, entries, count * sizeof(TreeEntry));
  qsort(sorted, count, sizeof(TreeEntry), entry_cmp);

  CdinHash h = cache_hash_str("tree:");

  for (size_t i = 0; i < count; i++) {
    
    CdinHash hn = cache_hash_str(sorted[i].name);
    CdinHash hh = cache_hash_bytes(&sorted[i].hash, sizeof(CdinHash));
    h = cache_hash_combine(h, cache_hash_combine(hn, hh));
  }

  free(sorted);
  return h;
}





CdinTreeCache *tree_cache_create(size_t max_entries) {
  CdinTreeCache *tc = calloc(1, sizeof(CdinTreeCache));
  if (!tc) return NULL;

  tc->capacity    = TREE_TABLE_SIZE;
  tc->max_entries = max_entries ? max_entries : 2048;
  tc->slots       = calloc(tc->capacity, sizeof(TreeSlot));
  if (!tc->slots) { free(tc); return NULL; }

  return tc;
}

void tree_cache_destroy(CdinTreeCache *tc) {
  if (!tc) return;
  for (size_t i = 0; i < tc->capacity; i++) {
    if (tc->slots[i].root[0]) snapshot_free(tc->slots[i].snap);
  }
  free(tc->slots);
  free(tc);
}

const TreeSnapshot *tree_cache_get(CdinTreeCache *tc, const char *root) {
  if (!tc || !root) return NULL;
  TreeSlot *s = tree_find(tc, root);
  if (!s || s->root[0] == '\0') return NULL;

  
  CdinHash meta = dir_meta_hash(root);
  if (meta == CDIN_HASH_NONE || s->root_meta_hash != meta) return NULL;

  return s->snap;
}

void tree_cache_put(CdinTreeCache *tc, TreeSnapshot *snap) {
  if (!tc || !snap) return;

  TreeSlot *s = tree_find(tc, snap->root);
  if (!s) return; 

  if (s->root[0] == '\0') {
    strncpy(s->root, snap->root, sizeof(s->root) - 1);
    s->root[sizeof(s->root) - 1] = '\0';
    tc->count++;
  } else {
    snapshot_free(s->snap);
  }

  s->root_meta_hash = dir_meta_hash(snap->root);
  s->snap           = snap;
}

bool tree_cache_is_valid(CdinTreeCache *tc, const char *root) {
  if (!tc || !root) return false;
  TreeSlot *s = tree_find(tc, root);
  if (!s || s->root[0] == '\0') return false;

  CdinHash meta = dir_meta_hash(root);
  return meta != CDIN_HASH_NONE && s->root_meta_hash == meta;
}

void tree_cache_invalidate(CdinTreeCache *tc, const char *root) {
  if (!tc || !root) return;
  size_t root_len = strlen(root);

  
  for (size_t i = 0; i < tc->capacity; i++) {
    TreeSlot *s = &tc->slots[i];
    if (s->root[0] == '\0') continue;
    if (strncmp(s->root, root, root_len) == 0) {
      snapshot_free(s->snap);
      s->snap    = NULL;
      s->root[0] = '\0';
      tc->count--;
    }
  }
}