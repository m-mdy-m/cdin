#ifndef TREE_CACHE_H
#define TREE_CACHE_H

#include "node.h"
#include <stddef.h>

TreeNode *file_tree_build(const char *root, const char *ignore_pat);
void      file_tree_free(TreeNode *root);
size_t    file_tree_flatten(const TreeNode *root, TreeNode **out_list,
                            size_t max_entries);

#endif