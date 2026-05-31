#ifndef NODE_H
#define NODE_H

#include <stddef.h>
#include <stdbool.h>

typedef struct TreeNode {
    char  name[256];
    char  path[1024];
    bool  is_dir;
    bool  expanded;

    struct TreeNode **children;
    size_t            nchildren;
} TreeNode;

TreeNode *node_create(const char *name, const char *path, bool is_dir);
void      node_destroy(TreeNode *n);
bool      node_add_child(TreeNode *parent, TreeNode *child);
void      node_sort_children(TreeNode *n);
int       node_cmp(const void *a, const void *b);

#endif