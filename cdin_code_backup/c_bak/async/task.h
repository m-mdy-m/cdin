#ifndef TASK_H
#define TASK_H

#include "chan.h"
#include <SDL3/SDL.h>
#include <stdbool.h>

/* fn receives its arg and the channel to post results to */
typedef void (*TaskFn)(void *arg, Chan *result);

typedef struct {
    SDL_Thread *thread;
    Chan       *chan;
} Task;

Task *task_create(TaskFn fn, void *arg, size_t result_size);
bool  task_poll(Task *t, void *out);
void  task_destroy(Task *t);

#endif