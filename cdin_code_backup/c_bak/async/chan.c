#include "chan.h"
#include <stdlib.h>
#include <string.h>

Chan *chan_create(size_t item_size) {
    Chan *c = calloc(1, sizeof(Chan));
    if (!c) return NULL;
    c->item_size = item_size;
    c->buf = malloc(item_size);
    if (!c->buf) { free(c); return NULL; }
    c->has_item = false;
    c->mu = (SDL_Mutex *)SDL_CreateMutex();
    c->cond = (SDL_Condition *)SDL_CreateCondition();
    return c;
}

void chan_destroy(Chan *c) {
    if (!c) return;
    SDL_DestroyMutex((SDL_Mutex *)c->mu);
    SDL_DestroyCondition((SDL_Condition *)c->cond);
    free(c->buf);
    free(c);
}

/* Overwrite the slot with a new value (producer, non-blocking) */
void chan_send(Chan *c, const void *item) {
    SDL_LockMutex((SDL_Mutex *)c->mu);
    memcpy(c->buf, item, c->item_size);
    c->has_item = true;
    SDL_SignalCondition((SDL_Condition *)c->cond);
    SDL_UnlockMutex((SDL_Mutex *)c->mu);
}

/* Try to receive — returns true and copies into out if there is a value */
bool chan_try_recv(Chan *c, void *out) {
    SDL_LockMutex((SDL_Mutex *)c->mu);
    bool got = c->has_item;
    if (got) {
        memcpy(out, c->buf, c->item_size);
        c->has_item = false;
    }
    SDL_UnlockMutex((SDL_Mutex *)c->mu);
    return got;
}