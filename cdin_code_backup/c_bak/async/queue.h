#ifndef QUEUE_H
#define QUEUE_H

#include <stddef.h>
#include <stdbool.h>

typedef struct Queue Queue;

Queue  *queue_create(size_t cap);
void    queue_destroy(Queue *q);
bool    queue_push(Queue *q, void *item);
void   *queue_pop(Queue *q);
size_t  queue_len(const Queue *q);

#endif