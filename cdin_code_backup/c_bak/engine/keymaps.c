#include "keymaps.h"
#include "editor.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* ── helpers ── */

static bool key_eq(const char *a, const char *b) {
    return strcmp(a, b) == 0;
}

/* ── NORMAL mode ── */

KeyAction keymap_normal(Editor *e, const char *key, bool ctrl) {
    /* count prefix: not stored here — handled by the Lua command layer above */

    /* --- mode switches --- */
    if (key_eq(key, "i"))          { editor_set_mode(e, MODE_INSERT);  return KA_MODE_CHANGE; }
    if (key_eq(key, "a")) {
        /* insert after cursor */
        editor_move(e, DIR_RIGHT, 1);
        editor_set_mode(e, MODE_INSERT);
        return KA_MODE_CHANGE;
    }
    if (key_eq(key, "capital i")) {  /* I — insert at line start */
        editor_move_line_start(e);
        editor_set_mode(e, MODE_INSERT);
        return KA_MODE_CHANGE;
    }
    if (key_eq(key, "capital a")) {  /* A — append at line end */
        editor_move_line_end(e);
        editor_set_mode(e, MODE_INSERT);
        return KA_MODE_CHANGE;
    }
    if (key_eq(key, "o"))          { editor_open_line_below(e);         return KA_MODE_CHANGE; }
    if (key_eq(key, "capital o"))  { editor_open_line_above(e);         return KA_MODE_CHANGE; }
    if (key_eq(key, "v"))          { editor_set_mode(e, MODE_VISUAL);
                                     e->sel_anchor = e->cursor;         return KA_MODE_CHANGE; }
    if (key_eq(key, ";") || (ctrl && key_eq(key, ";")))
                                   { editor_set_mode(e, MODE_COMMAND);  return KA_MODE_CHANGE; }

    /* --- movement: hjkl + arrows --- */
    if (key_eq(key, "h") || key_eq(key, "left"))   { editor_move(e, DIR_LEFT,  1); return KA_MOVED; }
    if (key_eq(key, "l") || key_eq(key, "right"))  { editor_move(e, DIR_RIGHT, 1); return KA_MOVED; }
    if (key_eq(key, "k") || key_eq(key, "up"))     { editor_move(e, DIR_UP,    1); return KA_MOVED; }
    if (key_eq(key, "j") || key_eq(key, "down"))   { editor_move(e, DIR_DOWN,  1); return KA_MOVED; }

    /* --- word motion --- */
    if (key_eq(key, "w"))   { editor_move_word_forward(e);  return KA_MOVED; }
    if (key_eq(key, "b"))   { editor_move_word_backward(e); return KA_MOVED; }

    /* --- line motion --- */
    if (key_eq(key, "0") || key_eq(key, "home"))  { editor_move_line_start(e); return KA_MOVED; }
    if (key_eq(key, "$") || key_eq(key, "end"))   { editor_move_line_end(e);   return KA_MOVED; }

    /* --- page motion (ctrl+f/b or pageup/pagedown) --- */
    if ((ctrl && key_eq(key, "f")) || key_eq(key, "pagedown")) return KA_PAGE_DOWN;
    if ((ctrl && key_eq(key, "b")) || key_eq(key, "pageup"))   return KA_PAGE_UP;

    /* --- document edges --- */
    if (key_eq(key, "g")) /* gg handled by repeating g */        return KA_NONE;
    if (ctrl && key_eq(key, "end"))   { editor_move_to_line(e, e->buf->lines - 1); return KA_MOVED; }
    if (ctrl && key_eq(key, "home"))  { editor_move_to_line(e, 0);                 return KA_MOVED; }

    /* --- editing --- */
    if (key_eq(key, "x"))           { editor_delete_char(e);   return KA_EDITED; }
    if (key_eq(key, "d") && ctrl)   { editor_delete_line(e);   return KA_EDITED; } /* ctrl+d = dd shortcut */

    /* --- search --- */
    if (key_eq(key, "/"))           return KA_SEARCH_FWD;
    if (key_eq(key, "?"))           return KA_SEARCH_BWD;
    if (key_eq(key, "n"))           { editor_search_next(e);   return KA_MOVED; }
    if (key_eq(key, "capital n"))   { editor_search_prev(e);   return KA_MOVED; }

    /* --- save/quit via : --- handled by MODE_COMMAND --- */

    /* --- undo / redo (plumbed through Lua doc layer) --- */
    if (ctrl && key_eq(key, "z"))   return KA_UNDO;
    if (ctrl && key_eq(key, "r"))   return KA_REDO;

    return KA_NONE;
}

/* ── INSERT mode ── */

KeyAction keymap_insert(Editor *e, const char *key, bool ctrl) {
    /* escape → back to normal */
    if (key_eq(key, "escape")) {
        editor_set_mode(e, MODE_NORMAL);
        return KA_MODE_CHANGE;
    }

    /* arrow keys still work in insert */
    if (key_eq(key, "left"))   { editor_move(e, DIR_LEFT,  1); return KA_MOVED; }
    if (key_eq(key, "right"))  { editor_move(e, DIR_RIGHT, 1); return KA_MOVED; }
    if (key_eq(key, "up"))     { editor_move(e, DIR_UP,    1); return KA_MOVED; }
    if (key_eq(key, "down"))   { editor_move(e, DIR_DOWN,  1); return KA_MOVED; }

    if (key_eq(key, "home"))   { editor_move_line_start(e); return KA_MOVED; }
    if (key_eq(key, "end"))    { editor_move_line_end(e);   return KA_MOVED; }

    /* delete / backspace */
    if (key_eq(key, "backspace") || (ctrl && key_eq(key, "h"))) {
        editor_delete_char(e);
        return KA_EDITED;
    }
    if (key_eq(key, "delete")) {
        /* forward delete: move right, then backspace */
        if (e->cursor.offset < buf_length(e->buf)) {
            buf_delete(e->buf, e->cursor.offset, 1);
        }
        return KA_EDITED;
    }

    /* return / newline */
    if (key_eq(key, "return") || key_eq(key, "keypad enter")) {
        editor_insert_char(e, '\n');
        return KA_EDITED;
    }

    /* tab */
    if (key_eq(key, "tab")) {
        /* insert 2 spaces (mirrors config.indent_size = 2) */
        editor_insert_char(e, ' ');
        editor_insert_char(e, ' ');
        return KA_EDITED;
    }

    /* ctrl+s → save */
    if (ctrl && key_eq(key, "s")) return KA_SAVE;

    /* printable characters are handled by the textinput event, not keypressed */
    return KA_NONE;
}

/* ── VISUAL mode ── */

KeyAction keymap_visual(Editor *e, const char *key, bool ctrl) {
    (void)ctrl;
    if (key_eq(key, "escape") || key_eq(key, "v")) {
        editor_set_mode(e, MODE_NORMAL);
        return KA_MODE_CHANGE;
    }

    /* same movement as normal */
    if (key_eq(key, "h") || key_eq(key, "left"))   { editor_move(e, DIR_LEFT,  1); return KA_MOVED; }
    if (key_eq(key, "l") || key_eq(key, "right"))  { editor_move(e, DIR_RIGHT, 1); return KA_MOVED; }
    if (key_eq(key, "k") || key_eq(key, "up"))     { editor_move(e, DIR_UP,    1); return KA_MOVED; }
    if (key_eq(key, "j") || key_eq(key, "down"))   { editor_move(e, DIR_DOWN,  1); return KA_MOVED; }
    if (key_eq(key, "w"))   { editor_move_word_forward(e);  return KA_MOVED; }
    if (key_eq(key, "b"))   { editor_move_word_backward(e); return KA_MOVED; }

    /* delete selection */
    if (key_eq(key, "d") || key_eq(key, "x")) return KA_VISUAL_DELETE;

    /* yank (copy): handled by caller */
    if (key_eq(key, "y")) return KA_VISUAL_YANK;

    return KA_NONE;
}

/* ── COMMAND mode ── */

KeyAction keymap_command(Editor *e, const char *key, bool ctrl) {
    (void)ctrl;

    if (key_eq(key, "escape")) {
        editor_set_mode(e, MODE_NORMAL);
        return KA_MODE_CHANGE;
    }
    if (key_eq(key, "return") || key_eq(key, "keypad enter")) {
        return KA_CMD_SUBMIT;
    }
    if (key_eq(key, "backspace")) {
        editor_cmdline_pop(e);
        if (e->cmdlen == 0) {
            editor_set_mode(e, MODE_NORMAL);
            return KA_MODE_CHANGE;
        }
        return KA_NONE;
    }

    /* single printable key: append to cmdline */
    if (strlen(key) == 1) {
        editor_cmdline_push(e, key[0]);
        return KA_NONE;
    }

    return KA_NONE;
}

/* ── top-level dispatcher ── */

KeyAction keymap_dispatch(Editor *e, const char *key, bool ctrl) {
    switch (e->mode) {
    case MODE_NORMAL:  return keymap_normal(e, key, ctrl);
    case MODE_INSERT:  return keymap_insert(e, key, ctrl);
    case MODE_VISUAL:  return keymap_visual(e, key, ctrl);
    case MODE_COMMAND: return keymap_command(e, key, ctrl);
    default:           return KA_NONE;
    }
}

/*
 * Execute a submitted command line (called when KA_CMD_SUBMIT is returned).
 * Returns a CommandResult so the caller knows what happened.
 */
CmdResult keymap_exec_command(Editor *e) {
    const char *cmd = e->cmdline;

    /* :w — write */
    if (strcmp(cmd, "w") == 0) {
        bool ok = editor_save(e, NULL);
        editor_set_mode(e, MODE_NORMAL);
        return ok ? CMD_SAVED : CMD_ERROR;
    }
    /* :q — quit */
    if (strcmp(cmd, "q") == 0) {
        if (e->buf->dirty) return CMD_UNSAVED;
        editor_set_mode(e, MODE_NORMAL);
        return CMD_QUIT;
    }
    /* :q! — force quit */
    if (strcmp(cmd, "q!") == 0) {
        editor_set_mode(e, MODE_NORMAL);
        return CMD_QUIT;
    }
    /* :wq or :x — write then quit */
    if (strcmp(cmd, "wq") == 0 || strcmp(cmd, "x") == 0) {
        editor_save(e, NULL);
        editor_set_mode(e, MODE_NORMAL);
        return CMD_QUIT;
    }
    /* :<number> — go to line */
    {
        char *end;
        long n = strtol(cmd, &end, 10);
        if (*end == '\0' && n > 0) {
            editor_move_to_line(e, (size_t)(n - 1));
            editor_set_mode(e, MODE_NORMAL);
            return CMD_OK;
        }
    }

    editor_set_mode(e, MODE_NORMAL);
    return CMD_UNKNOWN;
}