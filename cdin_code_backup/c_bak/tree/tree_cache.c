#include "tree_cache.h"
#include "node.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <dirent.h>
#include <sys/stat.h>

#define MAX_DEPTH 16   /* don't recurse deeper than this */

/* ── internal scanner ── */

static TreeNode *scan_dir(const char *path, int depth, const char *ignore_pat) {
    if (depth > MAX_DEPTH) return NULL;

    DIR *dir = opendir(path);
    if (!dir) return NULL;

    /* get the directory name from the path */
    const char *name = strrchr(path, '/');
    name = name ? name + 1 : path;

    TreeNode *node = node_create(name, path, true);
    if (!node) { closedir(dir); return NULL; }

    struct dirent *entry;
    while ((entry = readdir(dir))) {
        /* skip hidden and . / .. */
        if (entry->d_name[0] == '.') continue;
        /* skip if matches ignore pattern (simple prefix match) */
        if (ignore_pat && strncmp(entry->d_name, ignore_pat,
                                  strlen(ignore_pat)) == 0) continue;

        char child_path[1024];
        snprintf(child_path, sizeof(child_path), "%s/%s", path, entry->d_name);

        struct stat st;
        if (stat(child_path, &st) != 0) continue;

        TreeNode *child;
        if (S_ISDIR(st.st_mode)) {
            child = scan_dir(child_path, depth + 1, ignore_pat);
        } else if (S_ISREG(st.st_mode)) {
            child = node_create(entry->d_name, child_path, false);
        } else {
            continue;
        }

        if (child) {
            if (!node_add_child(node, child)) {
                node_destroy(child);
            }
        }
    }
    closedir(dir);
    node_sort_children(node);
    return node;
}

/* ── public API ── */

TreeNode *file_tree_build(const char *root, const char *ignore_pat) {
    return scan_dir(root, 0, ignore_pat);
}

void file_tree_free(TreeNode *root) {
    node_destroy(root);
}

size_t file_tree_flatten(const TreeNode *root, TreeNode **out_list,
                         size_t max_entries) {
    if (!root || !out_list || max_entries == 0) return 0;
    size_t count = 0;

    const TreeNode *stack[1024];
    int top = 0;
    stack[top++] = root;

    while (top > 0 && count < max_entries) {
        const TreeNode *n = stack[--top];
        out_list[count++] = (TreeNode *)n;
        if (n->is_dir && n->expanded) {
            /* push children in reverse so they come out in order */
            for (size_t i = n->nchildren; i > 0; i--) {
                if (top < (int)(sizeof(stack)/sizeof(stack[0])) - 1)
                    stack[top++] = n->children[i - 1];
            }
        }
    }
    return count;
}