#ifndef JOB_H
#define JOB_H

#include <SDL3/SDL.h>

typedef void (*JobFn)(void *arg);

SDL_Thread *job_spawn(JobFn fn, void *arg);

#endif