#ifndef EDITOR_H
#define EDITOR_H

#include "buffer.h"
#include <stddef.h>
#include <stdbool.h>

/* ── Vim-like modes ── */
typedef enum {
    MODE_NORMAL  = 0,
    MODE_INSERT  = 1,
    MODE_VISUAL  = 2,
    MODE_COMMAND = 3,
} EditorMode;

/* ── Movement directions ── */
typedef enum {
    DIR_UP    = 0,
    DIR_DOWN  = 1,
    DIR_LEFT  = 2,
    DIR_RIGHT = 3,
} Direction;

/* ── Cursor ── */
typedef struct {
    size_t line;    /* 0-indexed line number  */
    size_t col;     /* 0-indexed column       */
    size_t offset;  /* byte offset from start */
} Cursor;

/* ── Editor state ── */
typedef struct {
    Buffer     *buf;              /* the text buffer              */
    EditorMode  mode;             /* current mode                 */
    Cursor      cursor;           /* cursor position              */

    /* visual mode selection anchor */
    Cursor      sel_anchor;

    /* command-line buffer (for ':' commands) */
    char        cmdline[256];
    size_t      cmdlen;

    /* current search string */
    char        search[256];
} Editor;

/* lifecycle */
Editor *editor_create(void);
void    editor_destroy(Editor *e);

/* file I/O */
bool editor_open(Editor *e, const char *path);
bool editor_save(Editor *e, const char *path);

/* mode */
void editor_set_mode(Editor *e, EditorMode mode);

/* movement */
void editor_move(Editor *e, Direction dir, size_t count);
void editor_move_line_start(Editor *e);
void editor_move_line_end(Editor *e);
void editor_move_to_line(Editor *e, size_t line);
void editor_move_word_forward(Editor *e);
void editor_move_word_backward(Editor *e);

/* editing */
void editor_insert_char(Editor *e, char c);
void editor_delete_char(Editor *e);
void editor_delete_line(Editor *e);
void editor_open_line_below(Editor *e);
void editor_open_line_above(Editor *e);

/* command line */
void editor_cmdline_push(Editor *e, char c);
void editor_cmdline_pop(Editor *e);

/* search */
void   editor_search_set(Editor *e, const char *needle);
void   editor_search_next(Editor *e);
void   editor_search_prev(Editor *e);
size_t editor_find(const Editor *e, const char *needle, size_t from);

#endif