#include "task.h"
#include "job.h"
#include <stdlib.h>

typedef struct {
    TaskFn  fn;
    void   *arg;
    Chan   *result_chan;
} TaskCtx;

static void task_runner(void *data) {
    TaskCtx *ctx = (TaskCtx *)data;
    ctx->fn(ctx->arg, ctx->result_chan);
    free(ctx);
}

Task *task_create(TaskFn fn, void *arg, size_t result_size) {
    Task *t = calloc(1, sizeof(Task));
    if (!t) return NULL;

    t->chan = chan_create(result_size);
    if (!t->chan) { free(t); return NULL; }

    TaskCtx *ctx = malloc(sizeof(TaskCtx));
    if (!ctx) { chan_destroy(t->chan); free(t); return NULL; }

    ctx->fn          = fn;
    ctx->arg         = arg;
    ctx->result_chan  = t->chan;

    t->thread = job_spawn(task_runner, ctx);
    if (!t->thread) {
        chan_destroy(t->chan);
        free(ctx);
        free(t);
        return NULL;
    }
    return t;
}

bool task_poll(Task *t, void *out) {
    return chan_try_recv(t->chan, out);
}

void task_destroy(Task *t) {
    if (!t) return;
    /* detach — we don't wait for completion */
    SDL_DetachThread(t->thread);
    chan_destroy(t->chan);
    free(t);
}