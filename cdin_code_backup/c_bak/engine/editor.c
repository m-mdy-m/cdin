/*
 * editor.c — modal editor state (Vim-like)
 *
 * Keeps: cursor, mode, and the operations that mutate the buffer.
 * Does NOT know about rendering — that stays in the Lua layer / renderer.
 *
 * Modes:  NORMAL  — navigate, operate
 *         INSERT  — type text
 *         VISUAL  — select (character-wise)
 *         COMMAND — ":" command line
 */

#include "editor.h"
#include "buffer.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>

/* ── creation / destruction ── */

Editor *editor_create(void) {
    Editor *e = calloc(1, sizeof(Editor));
    if (!e) return NULL;
    e->buf    = buf_create();
    if (!e->buf) { free(e); return NULL; }
    e->mode   = MODE_NORMAL;
    e->cursor = (Cursor){ .line = 0, .col = 0, .offset = 0 };
    return e;
}

void editor_destroy(Editor *e) {
    if (!e) return;
    buf_destroy(e->buf);
    free(e);
}

/* ── cursor helpers ── */

/* Clamp cursor column to the actual line length */
static void cursor_clamp(Editor *e) {
    size_t line_len = buf_line_len(e->buf, e->cursor.line);
    /* In NORMAL mode the cursor can't sit on the newline itself */
    size_t max_col = (line_len == 0) ? 0 : line_len - 1;
    if (e->mode == MODE_INSERT) max_col = line_len;
    if (e->cursor.col > max_col) e->cursor.col = max_col;
}

/* Recompute byte offset from (line, col) */
static void cursor_sync_offset(Editor *e) {
    e->cursor.offset = buf_line_start(e->buf, e->cursor.line) + e->cursor.col;
}

/* Recompute (line, col) from byte offset */
static void cursor_sync_linecol(Editor *e) {
    size_t off = e->cursor.offset;
    size_t len = buf_length(e->buf);
    if (off > len) off = len;

    size_t line = 0, col = 0;
    for (size_t i = 0; i < off; i++) {
        if (buf_char_at(e->buf, i) == '\n') {
            line++;
            col = 0;
        } else {
            col++;
        }
    }
    e->cursor.line = line;
    e->cursor.col  = col;
}

/* ── movement ── */

void editor_move(Editor *e, Direction dir, size_t count) {
    size_t lines = e->buf->lines;

    for (size_t n = 0; n < count; n++) {
        switch (dir) {
        case DIR_UP:
            if (e->cursor.line > 0) e->cursor.line--;
            cursor_clamp(e);
            break;
        case DIR_DOWN:
            if (e->cursor.line + 1 < lines) e->cursor.line++;
            cursor_clamp(e);
            break;
        case DIR_LEFT:
            if (e->cursor.col > 0) {
                e->cursor.col--;
            } else if (e->cursor.line > 0) {
                e->cursor.line--;
                e->cursor.col = buf_line_len(e->buf, e->cursor.line);
                if (e->cursor.col > 0 && e->mode == MODE_NORMAL)
                    e->cursor.col--;
            }
            break;
        case DIR_RIGHT: {
            size_t line_len = buf_line_len(e->buf, e->cursor.line);
            size_t max = (e->mode == MODE_INSERT) ? line_len : (line_len > 0 ? line_len - 1 : 0);
            if (e->cursor.col < max) {
                e->cursor.col++;
            } else if (e->cursor.line + 1 < lines) {
                e->cursor.line++;
                e->cursor.col = 0;
            }
            break;
        }
        }
    }
    cursor_sync_offset(e);
}

void editor_move_line_start(Editor *e) {
    e->cursor.col = 0;
    cursor_sync_offset(e);
}

void editor_move_line_end(Editor *e) {
    size_t len = buf_line_len(e->buf, e->cursor.line);
    e->cursor.col = (len > 0 && e->mode == MODE_NORMAL) ? len - 1 : len;
    cursor_sync_offset(e);
}

void editor_move_to_line(Editor *e, size_t line) {
    size_t max_line = e->buf->lines > 0 ? e->buf->lines - 1 : 0;
    if (line > max_line) line = max_line;
    e->cursor.line = line;
    cursor_clamp(e);
    cursor_sync_offset(e);
}

/* word forward (simple: skip to next non-alnum boundary) */
void editor_move_word_forward(Editor *e) {
    size_t len = buf_length(e->buf);
    size_t off = e->cursor.offset;
    if (off >= len) return;

    /* skip current word */
    while (off < len) {
        char c = buf_char_at(e->buf, off);
        if (c == ' ' || c == '\t' || c == '\n') break;
        off++;
    }
    /* skip whitespace */
    while (off < len) {
        char c = buf_char_at(e->buf, off);
        if (c != ' ' && c != '\t' && c != '\n') break;
        off++;
    }
    e->cursor.offset = off;
    cursor_sync_linecol(e);
}

void editor_move_word_backward(Editor *e) {
    size_t off = e->cursor.offset;
    if (off == 0) return;
    off--;

    /* skip whitespace backward */
    while (off > 0) {
        char c = buf_char_at(e->buf, off);
        if (c != ' ' && c != '\t' && c != '\n') break;
        off--;
    }
    /* skip word backward */
    while (off > 0) {
        char c = buf_char_at(e->buf, off - 1);
        if (c == ' ' || c == '\t' || c == '\n') break;
        off--;
    }
    e->cursor.offset = off;
    cursor_sync_linecol(e);
}

/* ── mode transitions ── */

void editor_set_mode(Editor *e, EditorMode mode) {
    if (e->mode == mode) return;
    e->mode = mode;

    if (mode == MODE_NORMAL) {
        /* in normal mode col can't be past end */
        size_t line_len = buf_line_len(e->buf, e->cursor.line);
        if (line_len > 0 && e->cursor.col >= line_len)
            e->cursor.col = line_len - 1;
        cursor_sync_offset(e);
    }

    if (mode == MODE_COMMAND) {
        e->cmdline[0] = '\0';
        e->cmdlen = 0;
    }
}

/* ── insert / delete ── */

void editor_insert_char(Editor *e, char c) {
    if (e->mode != MODE_INSERT) return;
    buf_insert(e->buf, e->cursor.offset, &c, 1);
    e->cursor.offset++;
    if (c == '\n') {
        e->cursor.line++;
        e->cursor.col = 0;
    } else {
        e->cursor.col++;
    }
}

void editor_delete_char(Editor *e) {
    /* backspace in INSERT, 'x' in NORMAL */
    if (e->mode == MODE_INSERT) {
        if (e->cursor.offset == 0) return;
        char deleted = buf_char_at(e->buf, e->cursor.offset - 1);
        buf_delete(e->buf, e->cursor.offset - 1, 1);
        e->cursor.offset--;
        if (deleted == '\n') {
            e->cursor.line--;
            e->cursor.col = buf_line_len(e->buf, e->cursor.line);
        } else {
            if (e->cursor.col > 0) e->cursor.col--;
        }
    } else {
        /* normal mode: delete char under cursor */
        size_t len = buf_length(e->buf);
        if (e->cursor.offset >= len) return;
        buf_delete(e->buf, e->cursor.offset, 1);
        cursor_clamp(e);
        cursor_sync_offset(e);
    }
}

void editor_delete_line(Editor *e) {
    size_t start = buf_line_start(e->buf, e->cursor.line);
    size_t line_len = buf_line_len(e->buf, e->cursor.line);
    /* delete text + newline */
    buf_delete(e->buf, start, line_len + 1);
    size_t total_lines = e->buf->lines;
    if (e->cursor.line >= total_lines && total_lines > 0)
        e->cursor.line = total_lines - 1;
    cursor_clamp(e);
    cursor_sync_offset(e);
}

/* open new line below (Vim 'o') */
void editor_open_line_below(Editor *e) {
    size_t start = buf_line_start(e->buf, e->cursor.line);
    size_t line_len = buf_line_len(e->buf, e->cursor.line);
    size_t end = start + line_len;
    buf_insert(e->buf, end, "\n", 1);
    e->cursor.line++;
    e->cursor.col = 0;
    cursor_sync_offset(e);
    editor_set_mode(e, MODE_INSERT);
}

/* open new line above (Vim 'O') */
void editor_open_line_above(Editor *e) {
    size_t start = buf_line_start(e->buf, e->cursor.line);
    buf_insert(e->buf, start, "\n", 1);
    e->cursor.col = 0;
    cursor_sync_offset(e);
    editor_set_mode(e, MODE_INSERT);
}

/* ── command line ── */

void editor_cmdline_push(Editor *e, char c) {
    if (e->cmdlen + 1 >= sizeof(e->cmdline)) return;
    e->cmdline[e->cmdlen++] = c;
    e->cmdline[e->cmdlen]   = '\0';
}

void editor_cmdline_pop(Editor *e) {
    if (e->cmdlen == 0) return;
    e->cmdline[--e->cmdlen] = '\0';
}

/* ── file ops (thin wrappers) ── */

bool editor_open(Editor *e, const char *path) {
    return buf_load(e->buf, path);
}

bool editor_save(Editor *e, const char *path) {
    return buf_save(e->buf, path);
}

/* ── search ── */

/* Simple forward search; returns byte offset or SIZE_MAX if not found */
size_t editor_find(const Editor *e, const char *needle, size_t from) {
    size_t nlen = strlen(needle);
    size_t total = buf_length(e->buf);
    if (nlen == 0 || total == 0 || from >= total) return SIZE_MAX;

    for (size_t i = from; i + nlen <= total; i++) {
        bool match = true;
        for (size_t j = 0; j < nlen; j++) {
            if (buf_char_at(e->buf, i + j) != needle[j]) {
                match = false; break;
            }
        }
        if (match) return i;
    }
    return SIZE_MAX;
}

void editor_search_set(Editor *e, const char *needle) {
    strncpy(e->search, needle, sizeof(e->search) - 1);
    e->search[sizeof(e->search) - 1] = '\0';
}

void editor_search_next(Editor *e) {
    if (!e->search[0]) return;
    size_t found = editor_find(e, e->search, e->cursor.offset + 1);
    if (found == SIZE_MAX) {
        /* wrap */
        found = editor_find(e, e->search, 0);
    }
    if (found != SIZE_MAX) {
        e->cursor.offset = found;
        cursor_sync_linecol(e);
    }
}

void editor_search_prev(Editor *e) {
    if (!e->search[0]) return;
    size_t nlen  = strlen(e->search);
    size_t start = e->cursor.offset;
    if (start < nlen) start = 0;
    else start -= nlen;

    /* backward: scan from start down to 0 */
    for (size_t i = start; ; i--) {
        size_t found = editor_find(e, e->search, i);
        if (found < e->cursor.offset) {
            e->cursor.offset = found;
            cursor_sync_linecol(e);
            return;
        }
        if (i == 0) break;
    }
}