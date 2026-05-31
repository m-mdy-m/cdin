/*
 * node.c — file-tree node
 *
 * Represents a single entry (file or directory) in the project tree.
 * Kept minimal: just allocation, free, and a sort comparator.
 * The actual tree building lives in tree_cache.c.
 */

#include "node.h"
#include <stdlib.h>
#include <string.h>

TreeNode *node_create(const char *name, const char *path, bool is_dir) {
    TreeNode *n = calloc(1, sizeof(TreeNode));
    if (!n) return NULL;
    strncpy(n->name, name, sizeof(n->name) - 1);
    strncpy(n->path, path, sizeof(n->path) - 1);
    n->is_dir   = is_dir;
    n->expanded = false;
    n->children = NULL;
    n->nchildren = 0;
    return n;
}

void node_destroy(TreeNode *n) {
    if (!n) return;
    for (size_t i = 0; i < n->nchildren; i++) {
        node_destroy(n->children[i]);
    }
    free(n->children);
    free(n);
}

/* Sort: directories first, then alphabetical */
int node_cmp(const void *a, const void *b) {
    const TreeNode *na = *(const TreeNode **)a;
    const TreeNode *nb = *(const TreeNode **)b;
    if (na->is_dir != nb->is_dir)
        return na->is_dir ? -1 : 1;
    return strcmp(na->name, nb->name);
}

bool node_add_child(TreeNode *parent, TreeNode *child) {
    size_t new_count = parent->nchildren + 1;
    TreeNode **arr = realloc(parent->children, new_count * sizeof(TreeNode *));
    if (!arr) return false;
    arr[parent->nchildren] = child;
    parent->children = arr;
    parent->nchildren = new_count;
    return true;
}

void node_sort_children(TreeNode *n) {
    if (n->nchildren > 1) {
        qsort(n->children, n->nchildren, sizeof(TreeNode *), node_cmp);
    }
}