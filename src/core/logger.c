#include "logger.h"
#include <string.h>

#define MAX_CALLBACKS 32

typedef struct {
  log_LogFn fn;
  void *udata;
  int level;
} Callback;

static struct {
  void        *udata;
  log_LockFn   lock;
  int          level;
  bool         quiet;
  Callback     callbacks[MAX_CALLBACKS];
} L;


static const char *level_strings[] = {
  "TRACE", "DEBUG", "INFO ", "WARN ", "ERROR", "FATAL"
};

#ifdef LOG_USE_COLOR
static const char *level_colors[] = {
  "\x1b[90m",   /* TRACE — dark grey   */
  "\x1b[36m",   /* DEBUG — cyan        */
  "\x1b[32m",   /* INFO  — green       */
  "\x1b[33m",   /* WARN  — yellow      */
  "\x1b[31m",   /* ERROR — red         */
  "\x1b[35m",   /* FATAL — magenta     */
};
#endif


static void stderr_callback(log_Event *ev) {
  char tbuf[16];
  tbuf[strftime(tbuf, sizeof(tbuf), "%H:%M:%S", ev->time)] = '\0';

  const char *file = strrchr(ev->file, '/');
  file = file ? file + 1 : ev->file;
#ifdef _WIN32
  const char *file2 = strrchr(file, '\\');
  if (file2) file = file2 + 1;
#endif

#ifdef LOG_USE_COLOR
  fprintf(ev->udata,
    "%s %s%-5s\x1b[0m \x1b[90m%-18s:%3d\x1b[0m  ",
    tbuf,
    level_colors[ev->level],
    level_strings[ev->level],
    file,
    ev->line);
#else
  fprintf(ev->udata,
    "%s %-5s %-18s:%3d  ",
    tbuf,
    level_strings[ev->level],
    file,
    ev->line);
#endif
  vfprintf(ev->udata, ev->fmt, ev->ap);
  fprintf(ev->udata, "\n");
  fflush(ev->udata);
}


static void file_callback(log_Event *ev) {
  char tbuf[32];
  tbuf[strftime(tbuf, sizeof(tbuf), "%Y-%m-%d %H:%M:%S", ev->time)] = '\0';

  const char *file = strrchr(ev->file, '/');
  file = file ? file + 1 : ev->file;

  fprintf(ev->udata,
    "%s %-5s %-22s:%3d  ",
    tbuf,
    level_strings[ev->level],
    file,
    ev->line);
  vfprintf(ev->udata, ev->fmt, ev->ap);
  fprintf(ev->udata, "\n");
  fflush(ev->udata);
}


static void do_lock(void)   { if (L.lock) L.lock(true,  L.udata); }
static void do_unlock(void) { if (L.lock) L.lock(false, L.udata); }


const char *log_level_string(int level) {
  return level_strings[level];
}

void log_set_lock(log_LockFn fn, void *udata) {
  L.lock  = fn;
  L.udata = udata;
}

void log_set_level(int level) { L.level = level; }
void log_set_quiet(bool enable) { L.quiet = enable; }

int log_add_callback(log_LogFn fn, void *udata, int level) {
  for (int i = 0; i < MAX_CALLBACKS; i++) {
    if (!L.callbacks[i].fn) {
      L.callbacks[i] = (Callback){ fn, udata, level };
      return 0;
    }
  }
  return -1; /* no free slot */
}

int log_add_fp(FILE *fp, int level) {
  return log_add_callback(file_callback, fp, level);
}


static void init_event(log_Event *ev, void *udata) {
  if (!ev->time) {
    time_t t = time(NULL);
    ev->time = localtime(&t);
  }
  ev->udata = udata;
}


void log_log(int level, const char *file, int line, const char *fmt, ...) {
  log_Event ev = {
    .fmt   = fmt,
    .file  = file,
    .line  = line,
    .level = level,
  };

  do_lock();

  if (!L.quiet && level >= L.level) {
    init_event(&ev, stderr);
    va_start(ev.ap, fmt);
    stderr_callback(&ev);
    va_end(ev.ap);
  }

  for (int i = 0; i < MAX_CALLBACKS && L.callbacks[i].fn; i++) {
    Callback *cb = &L.callbacks[i];
    if (level >= cb->level) {
      init_event(&ev, cb->udata);
      va_start(ev.ap, fmt);
      cb->fn(&ev);
      va_end(ev.ap);
    }
  }

  do_unlock();
}
