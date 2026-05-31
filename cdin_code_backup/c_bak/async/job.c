#include "job.h"
#include <stdlib.h>

typedef struct {
    JobFn  fn;
    void  *arg;
} JobCtx;

static int job_thread(void *data) {
    JobCtx *ctx = (JobCtx *)data;
    ctx->fn(ctx->arg);
    free(ctx);
    return 0;
}

SDL_Thread *job_spawn(JobFn fn, void *arg) {
    JobCtx *ctx = malloc(sizeof(JobCtx));
    if (!ctx) return NULL;
    ctx->fn  = fn;
    ctx->arg = arg;
    return SDL_CreateThread(job_thread, "cdin-job", ctx);
}