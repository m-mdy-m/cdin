/*
 * buffer.c — gap buffer for text editing
 *
 * A gap buffer keeps a "gap" (empty space) at the cursor position so that
 * inserts and deletes at that position are O(1). Moving the cursor slides
 * the gap, which is O(n) in distance — acceptable for a text editor.
 *
 * Layout:  [ text before gap | GAP | text after gap ]
 *           0 .. gap_start-1   gap  gap_end .. size-1
 */

#include "buffer.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define GAP_MIN   256    /* minimum gap size in bytes */
#define GAP_GROW  4096   /* how much to grow by when gap is exhausted */

/* ── internal helpers ── */

static bool buf_ensure_gap(Buffer *b, size_t needed) {
    size_t gap_size = b->gap_end - b->gap_start;
    if (gap_size >= needed) return true;

    size_t new_gap = needed + GAP_GROW;
    size_t old_size = b->size;
    size_t new_size = old_size + (new_gap - gap_size);

    char *mem = realloc(b->data, new_size);
    if (!mem) return false;
    b->data = mem;

    /* slide the post-gap text to the end of the new allocation */
    size_t after_len = old_size - b->gap_end;
    memmove(b->data + new_size - after_len,
            b->data + b->gap_end,
            after_len);

    b->gap_end = new_size - after_len;
    b->size    = new_size;
    return true;
}

static void buf_move_gap_to(Buffer *b, size_t pos) {
    if (pos == b->gap_start) return;

    size_t gap_len = b->gap_end - b->gap_start;

    if (pos < b->gap_start) {
        /* move gap left */
        size_t delta = b->gap_start - pos;
        memmove(b->data + b->gap_end - delta,
                b->data + pos,
                delta);
        b->gap_start = pos;
        b->gap_end   = pos + gap_len;
    } else {
        /* move gap right (pos is a logical position, after gap) */
        size_t raw_pos = pos + gap_len; /* physical position */
        size_t delta   = raw_pos - b->gap_end;
        memmove(b->data + b->gap_start,
                b->data + b->gap_end,
                delta);
        b->gap_start = raw_pos - gap_len;
        b->gap_end   = raw_pos;
    }
}

/* logical length = physical size minus the gap */
static inline size_t buf_len(const Buffer *b) {
    return b->size - (b->gap_end - b->gap_start);
}

/* convert logical offset → physical index */
static inline size_t buf_phys(const Buffer *b, size_t log) {
    return log < b->gap_start ? log : log + (b->gap_end - b->gap_start);
}

/* ── public API ── */

Buffer *buf_create(void) {
    Buffer *b = calloc(1, sizeof(Buffer));
    if (!b) return NULL;

    b->size      = GAP_MIN;
    b->gap_start = 0;
    b->gap_end   = GAP_MIN;
    b->data      = malloc(GAP_MIN);
    if (!b->data) { free(b); return NULL; }

    b->dirty = false;
    b->lines = 1;
    return b;
}

void buf_destroy(Buffer *b) {
    if (!b) return;
    free(b->data);
    free(b);
}

bool buf_load(Buffer *b, const char *path) {
    if (!b || !path) return false;

    FILE *fp = fopen(path, "rb");
    if (!fp) return false;

    fseek(fp, 0, SEEK_END);
    long sz = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    if (sz < 0) { fclose(fp); return false; }

    /* reset buffer */
    b->gap_start = 0;
    b->gap_end   = 0;
    b->size      = 0;

    if (!buf_ensure_gap(b, (size_t)sz + GAP_MIN)) {
        fclose(fp);
        return false;
    }

    /* read directly after gap */
    size_t r = fread(b->data + b->gap_end, 1, (size_t)sz, fp);
    fclose(fp);

    b->size    = b->gap_end + r;

    /* count lines */
    b->lines = 1;
    for (size_t i = 0; i < r; i++) {
        if (b->data[b->gap_end + i] == '\n') b->lines++;
    }

    strncpy(b->path, path, sizeof(b->path) - 1);
    b->path[sizeof(b->path) - 1] = '\0';
    b->dirty = false;
    return true;
}

bool buf_save(Buffer *b, const char *path) {
    if (!b) return false;
    if (!path) path = b->path;
    if (!path[0]) return false;

    FILE *fp = fopen(path, "wb");
    if (!fp) return false;

    /* write in two parts around the gap */
    fwrite(b->data,            1, b->gap_start,               fp);
    fwrite(b->data + b->gap_end, 1, b->size - b->gap_end,      fp);
    fclose(fp);

    strncpy(b->path, path, sizeof(b->path) - 1);
    b->path[sizeof(b->path) - 1] = '\0';
    b->dirty = false;
    return true;
}

bool buf_insert(Buffer *b, size_t pos, const char *text, size_t len) {
    if (!b || !text || len == 0) return false;
    if (pos > buf_len(b)) pos = buf_len(b);

    if (!buf_ensure_gap(b, len)) return false;
    buf_move_gap_to(b, pos);

    memcpy(b->data + b->gap_start, text, len);
    b->gap_start += len;
    b->dirty = true;

    /* update line count */
    for (size_t i = 0; i < len; i++) {
        if (text[i] == '\n') b->lines++;
    }
    return true;
}

bool buf_delete(Buffer *b, size_t pos, size_t len) {
    if (!b || len == 0) return false;
    size_t total = buf_len(b);
    if (pos >= total) return false;
    if (pos + len > total) len = total - pos;

    buf_move_gap_to(b, pos);

    /* count newlines being removed */
    size_t phys = b->gap_end;
    for (size_t i = 0; i < len; i++) {
        if (b->data[phys + i] == '\n' && b->lines > 1) b->lines--;
    }

    b->gap_end += len;
    b->dirty = true;
    return true;
}

char buf_char_at(const Buffer *b, size_t pos) {
    if (!b || pos >= buf_len(b)) return '\0';
    return b->data[buf_phys(b, pos)];
}

size_t buf_copy(const Buffer *b, size_t pos, size_t len, char *out, size_t out_size) {
    if (!b || !out || out_size == 0) return 0;
    size_t total = buf_len(b);
    if (pos >= total) { out[0] = '\0'; return 0; }
    if (pos + len > total) len = total - pos;
    if (len >= out_size) len = out_size - 1;

    size_t copied = 0;
    for (size_t i = 0; i < len; i++) {
        out[copied++] = buf_char_at(b, pos + i);
    }
    out[copied] = '\0';
    return copied;
}

size_t buf_length(const Buffer *b) {
    return b ? buf_len(b) : 0;
}

/* Return the byte offset of the start of the given line (0-indexed) */
size_t buf_line_start(const Buffer *b, size_t line) {
    if (!b || line == 0) return 0;
    size_t total = buf_len(b);
    size_t cur_line = 0;
    for (size_t i = 0; i < total; i++) {
        if (buf_char_at(b, i) == '\n') {
            cur_line++;
            if (cur_line == line) return i + 1;
        }
    }
    return total;
}

/* Return length of line (not including the newline) */
size_t buf_line_len(const Buffer *b, size_t line) {
    size_t start = buf_line_start(b, line);
    size_t total = buf_len(b);
    size_t len   = 0;
    for (size_t i = start; i < total; i++) {
        char c = buf_char_at(b, i);
        if (c == '\n' || c == '\0') break;
        len++;
    }
    return len;
}