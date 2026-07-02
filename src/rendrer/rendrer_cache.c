#include <stdio.h>
#include "rencache.h"

#define CELLS_X          80
#define CELLS_Y          50
#define CELL_SIZE        96
#define COMMAND_BUF_SIZE (1024 * 512)

enum { FREE_FONT, SET_CLIP, DRAW_TEXT, DRAW_RECT };

typedef struct {
  int type, size;
  RenRect rect;
  RenColor color;
  RenFont *font;
  int tab_width;
  char text[0];
} Command;


static unsigned  cells_buf1[CELLS_X * CELLS_Y];
static unsigned  cells_buf2[CELLS_X * CELLS_Y];
static unsigned *cells_prev = cells_buf1;
static unsigned *cells      = cells_buf2;
static RenRect   rect_buf[CELLS_X * CELLS_Y / 2];
static char      command_buf[COMMAND_BUF_SIZE];
static int       command_buf_idx;
static RenRect   screen_rect;
static bool      show_debug;
static int frame_draw_text_count;
static int frame_draw_rect_count;
static int frame_buf_bytes_peak;


static inline int min(int a, int b) { return a < b ? a : b; }
static inline int max(int a, int b) { return a > b ? a : b; }

#define HASH_INITIAL 2166136261u

static void hash(unsigned *h, const void *data, int size) {
  const unsigned char *p = data;
  while (size--) {
    *h = (*h ^ *p++) * 16777619u;
  }
}

static inline int cell_idx(int x, int y) {
  return x + y * CELLS_X;
}

static inline bool rects_overlap(RenRect a, RenRect b) {
  return b.x + b.width  >= a.x && b.x <= a.x + a.width
      && b.y + b.height >= a.y && b.y <= a.y + a.height;
}

static RenRect intersect_rects(RenRect a, RenRect b) {
  int x1 = max(a.x, b.x);
  int y1 = max(a.y, b.y);
  int x2 = min(a.x + a.width,  b.x + b.width);
  int y2 = min(a.y + a.height, b.y + b.height);
  return (RenRect){ x1, y1, max(0, x2 - x1), max(0, y2 - y1) };
}

static RenRect merge_rects(RenRect a, RenRect b) {
  int x1 = min(a.x, b.x);
  int y1 = min(a.y, b.y);
  int x2 = max(a.x + a.width,  b.x + b.width);
  int y2 = max(a.y + a.height, b.y + b.height);
  return (RenRect){ x1, y1, x2 - x1, y2 - y1 };
}


static Command *push_command(int type, int size) {
  Command *cmd = (Command *)(command_buf + command_buf_idx);
  int n = command_buf_idx + size;
  if (n > COMMAND_BUF_SIZE) {
    fprintf(stderr, "Warning: (" __FILE__ "): exhausted command buffer\n");
    return NULL;
  }
  command_buf_idx = n;
  if (command_buf_idx > frame_buf_bytes_peak) {
    frame_buf_bytes_peak = command_buf_idx;
  }
  memset(cmd, 0, sizeof(Command));
  cmd->type = type;
  cmd->size = size;
  return cmd;
}

static bool next_command(Command **prev) {
  if (*prev == NULL) {
    *prev = (Command *)command_buf;
  } else {
    *prev = (Command *)(((char *)*prev) + (*prev)->size);
  }
  return *prev != (Command *)(command_buf + command_buf_idx);
}

void rencache_show_debug(bool enable) {
  log_info("rencache: debug overlay %s", enable ? "enabled" : "disabled");
  show_debug = enable;
}


void rencache_free_font(RenFont *font) {
  log_debug("rencache: queuing FREE_FONT command");
  Command *cmd = push_command(FREE_FONT, sizeof(Command));
  if (cmd) { cmd->font = font; }
}


void rencache_set_clip_rect(RenRect rect) {
  Command *cmd = push_command(SET_CLIP, sizeof(Command));
  if (cmd) {
    cmd->rect = intersect_rects(rect, screen_rect);
    log_trace("rencache: SET_CLIP → {%d,%d,%dx%d}",
              cmd->rect.x, cmd->rect.y, cmd->rect.width, cmd->rect.height);
  }
}


void rencache_draw_rect(RenRect rect, RenColor color) {
  if (!rects_overlap(screen_rect, rect)) return;
  Command *cmd = push_command(DRAW_RECT, sizeof(Command));
  if (cmd) {
    cmd->rect  = rect;
    cmd->color = color;
    frame_draw_rect_count++;
  }
}


int rencache_draw_text(RenFont *font, const char *text, int x, int y, RenColor color) {
  RenRect rect = {
    .x      = x,
    .y      = y,
    .width  = ren_get_font_width(font, text),
    .height = ren_get_font_height(font),
  };

  if (rects_overlap(screen_rect, rect)) {
    int sz  = (int)strlen(text) + 1;
    Command *cmd = push_command(DRAW_TEXT, (int)sizeof(Command) + sz);
    if (cmd) {
      memcpy(cmd->text, text, sz);
      cmd->color     = color;
      cmd->font      = font;
      cmd->rect      = rect;
      cmd->tab_width = ren_get_font_tab_width(font);
      frame_draw_text_count++;
    }
  }

  return x + rect.width;
}


void rencache_invalidate(void) {
  log_debug("rencache: full invalidation — all cells marked dirty");
  memset(cells_prev, 0xff, sizeof(cells_buf1));
}


void rencache_begin_frame(void) {
  frame_draw_text_count = 0;
  frame_draw_rect_count = 0;
  frame_buf_bytes_peak  = 0;

  int w, h;
  ren_get_size(&w, &h);
  if (screen_rect.width != w || screen_rect.height != h) {
    log_info("rencache: window resized from %dx%d to %dx%d — full invalidation",
             screen_rect.width, screen_rect.height, w, h);
    screen_rect.width  = w;
    screen_rect.height = h;
    rencache_invalidate();
  }
}


static void update_overlapping_cells(RenRect r, unsigned h) {
  int x1 = r.x / CELL_SIZE;
  int y1 = r.y / CELL_SIZE;
  int x2 = (r.x + r.width)  / CELL_SIZE;
  int y2 = (r.y + r.height)  / CELL_SIZE;

  for (int y = y1; y <= y2; y++) {
    for (int x = x1; x <= x2; x++) {
      int idx = cell_idx(x, y);
      hash(&cells[idx], &h, sizeof(h));
    }
  }
}

static void push_rect(RenRect r, int *count) {
  /* Try to merge with an existing dirty rect */
  for (int i = *count - 1; i >= 0; i--) {
    RenRect *rp = &rect_buf[i];
    if (rects_overlap(*rp, r)) {
      *rp = merge_rects(*rp, r);
      return;
    }
  }
  rect_buf[(*count)++] = r;
}


void rencache_end_frame(void) {
  /* Pass 1: hash all commands into the cell grid */
  Command *cmd = NULL;
  RenRect  cr  = screen_rect;
  int total_cmd = 0;
  while (next_command(&cmd)) {
    total_cmd++;
    if (cmd->type == SET_CLIP) { cr = cmd->rect; }
    RenRect r = intersect_rects(cmd->rect, cr);
    if (r.width == 0 || r.height == 0) continue;
    unsigned h = HASH_INITIAL;
    hash(&h, cmd, cmd->size);
    update_overlapping_cells(r, h);
  }

  /* Pass 2: find changed cells and collect dirty pixel rects */
  int rect_count = 0;
  int max_x = screen_rect.width  / CELL_SIZE + 1;
  int max_y = screen_rect.height / CELL_SIZE + 1;
  for (int y = 0; y < max_y; y++) {
    for (int x = 0; x < max_x; x++) {
      int idx = cell_idx(x, y);
      if (cells[idx] != cells_prev[idx]) {
        push_rect((RenRect){ x, y, 1, 1 }, &rect_count);
      }
      cells_prev[idx] = HASH_INITIAL;
    }
  }

  /* Expand from cell-space to pixel-space */
  for (int i = 0; i < rect_count; i++) {
    RenRect *r = &rect_buf[i];
    r->x      *= CELL_SIZE;
    r->y      *= CELL_SIZE;
    r->width  *= CELL_SIZE;
    r->height *= CELL_SIZE;
    *r = intersect_rects(*r, screen_rect);
  }

  log_trace("rencache: end_frame — cmds=%d dirty_rects=%d "
            "draw_text=%d draw_rect=%d buf=%d/%d bytes",
            total_cmd, rect_count,
            frame_draw_text_count, frame_draw_rect_count,
            frame_buf_bytes_peak, COMMAND_BUF_SIZE);

  bool has_free_commands = false;
  for (int i = 0; i < rect_count; i++) {
    RenRect r = rect_buf[i];
    ren_set_clip_rect(r);

    cmd = NULL;
    while (next_command(&cmd)) {
      switch (cmd->type) {
        case FREE_FONT:
          has_free_commands = true;
          break;
        case SET_CLIP:
          ren_set_clip_rect(intersect_rects(cmd->rect, r));
          break;
        case DRAW_RECT:
          ren_draw_rect(cmd->rect, cmd->color);
          break;
        case DRAW_TEXT:
          ren_set_font_tab_width(cmd->font, cmd->tab_width);
          ren_draw_text(cmd->font, cmd->text, cmd->rect.x, cmd->rect.y, cmd->color);
          break;
      }
    }

    if (show_debug) {
      RenColor color = { rand(), rand(), rand(), 50 };
      ren_draw_rect(r, color);
    }
  }

  if (rect_count > 0) {
    ren_update_rects(rect_buf, rect_count);
  }

  if (has_free_commands) {
    log_debug("rencache: processing FREE_FONT commands");
    cmd = NULL;
    while (next_command(&cmd)) {
      if (cmd->type == FREE_FONT) {
        ren_free_font(cmd->font);
      }
    }
  }

  unsigned *tmp = cells;
  cells         = cells_prev;
  cells_prev    = tmp;
  command_buf_idx = 0;
}