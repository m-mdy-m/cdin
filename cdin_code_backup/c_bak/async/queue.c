#include "queue.h"
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>

#define QUEUE_DEFAULT_CAP 64   /* must be power of 2 */

struct Queue {
    void         **slots;
    size_t         cap;        /* always a power of 2          */
    atomic_size_t  head;       /* consumer reads from head     */
    atomic_size_t  tail;       /* producer writes to tail      */
};

Queue *queue_create(size_t cap) {
    if (cap == 0) cap = QUEUE_DEFAULT_CAP;
    /* round up to power of two */
    size_t p = 1;
    while (p < cap) p <<= 1;

    Queue *q = calloc(1, sizeof(Queue));
    if (!q) return NULL;
    q->slots = calloc(p, sizeof(void *));
    if (!q->slots) { free(q); return NULL; }
    q->cap = p;
    atomic_init(&q->head, 0);
    atomic_init(&q->tail, 0);
    return q;
}

void queue_destroy(Queue *q) {
    if (!q) return;
    free(q->slots);
    free(q);
}

/* Producer: push pointer. Returns false if full. */
bool queue_push(Queue *q, void *item) {
    size_t tail = atomic_load_explicit(&q->tail, memory_order_relaxed);
    size_t head = atomic_load_explicit(&q->head, memory_order_acquire);
    if (tail - head >= q->cap) return false;   /* full */
    q->slots[tail & (q->cap - 1)] = item;
    atomic_store_explicit(&q->tail, tail + 1, memory_order_release);
    return true;
}

/* Consumer: pop pointer. Returns NULL if empty. */
void *queue_pop(Queue *q) {
    size_t head = atomic_load_explicit(&q->head, memory_order_relaxed);
    size_t tail = atomic_load_explicit(&q->tail, memory_order_acquire);
    if (head == tail) return NULL;   /* empty */
    void *item = q->slots[head & (q->cap - 1)];
    atomic_store_explicit(&q->head, head + 1, memory_order_release);
    return item;
}

size_t queue_len(const Queue *q) {
    size_t tail = atomic_load_explicit(&q->tail, memory_order_acquire);
    size_t head = atomic_load_explicit(&q->head, memory_order_acquire);
    return tail - head;
}