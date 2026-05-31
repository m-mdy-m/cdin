#ifndef KEYMAPS_H
#define KEYMAPS_H

#include "editor.h"
#include <stdbool.h>

/*
 * KeyAction — what the editor core wants the top layer to do.
 * The Lua layer reads this and updates the screen / performs I/O.
 */
typedef enum {
    KA_NONE         = 0,
    KA_MOVED        = 1,   /* cursor moved, redraw needed          */
    KA_EDITED       = 2,   /* buffer changed                       */
    KA_MODE_CHANGE  = 3,   /* mode changed                         */
    KA_PAGE_UP      = 4,   /* scroll a page up                     */
    KA_PAGE_DOWN    = 5,   /* scroll a page down                   */
    KA_SAVE         = 6,   /* save file (ctrl+s in insert)         */
    KA_UNDO         = 7,
    KA_REDO         = 8,
    KA_SEARCH_FWD   = 9,   /* enter search-forward mode            */
    KA_SEARCH_BWD   = 10,  /* enter search-backward mode           */
    KA_VISUAL_DELETE = 11,
    KA_VISUAL_YANK   = 12,
    KA_CMD_SUBMIT   = 13,  /* command line submitted               */
} KeyAction;

/*
 * CmdResult — result of executing a ':' command.
 */
typedef enum {
    CMD_OK      = 0,
    CMD_SAVED   = 1,
    CMD_QUIT    = 2,
    CMD_UNSAVED = 3,   /* tried :q with unsaved changes          */
    CMD_UNKNOWN = 4,
    CMD_ERROR   = 5,
} CmdResult;

/* Dispatch a key event to the current mode handler.
 * key  — SDL key name, already lower-cased (e.g. "a", "return", "left").
 * ctrl — true if ctrl is held. */
KeyAction  keymap_dispatch(Editor *e, const char *key, bool ctrl);

/* Execute the command stored in e->cmdline. */
CmdResult  keymap_exec_command(Editor *e);

/* Per-mode handlers (exposed for testing) */
KeyAction  keymap_normal (Editor *e, const char *key, bool ctrl);
KeyAction  keymap_insert (Editor *e, const char *key, bool ctrl);
KeyAction  keymap_visual (Editor *e, const char *key, bool ctrl);
KeyAction  keymap_command(Editor *e, const char *key, bool ctrl);

#endif