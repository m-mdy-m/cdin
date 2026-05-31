#ifndef BUFFER_H
#define BUFFER_H

#include <stddef.h>
#include <stdbool.h>

typedef struct {
    char  *data;          /* raw storage: [before gap][    gap    ][after gap] */
    size_t size;          /* total allocated bytes                              */
    size_t gap_start;     /* index of first gap byte                           */
    size_t gap_end;       /* index of first post-gap byte                      */

    size_t lines;         /* line count (newline count + 1)                    */
    bool   dirty;         /* modified since last save                          */
    char   path[1024];    /* file path, empty = unsaved                        */
} Buffer;

Buffer *buf_create(void);
void    buf_destroy(Buffer *b);

bool buf_load(Buffer *b, const char *path);
bool buf_save(Buffer *b, const char *path);

bool   buf_insert(Buffer *b, size_t pos, const char *text, size_t len);
bool   buf_delete(Buffer *b, size_t pos, size_t len);
char   buf_char_at(const Buffer *b, size_t pos);
size_t buf_copy(const Buffer *b, size_t pos, size_t len, char *out, size_t out_size);
size_t buf_length(const Buffer *b);
size_t buf_line_start(const Buffer *b, size_t line);
size_t buf_line_len(const Buffer *b, size_t line);

#endif