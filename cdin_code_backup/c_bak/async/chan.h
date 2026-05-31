#ifndef CHAN_H
#define CHAN_H

#include <stddef.h>
#include <stdbool.h>
#include <SDL3/SDL.h>

typedef struct {
    void          *buf;
    size_t         item_size;
    bool           has_item;
    SDL_Mutex     *mu;
    SDL_Condition *cond;
} Chan;

Chan *chan_create(size_t item_size);
void  chan_destroy(Chan *c);
void  chan_send(Chan *c, const void *item);
bool  chan_try_recv(Chan *c, void *out);

#endif