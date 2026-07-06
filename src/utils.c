#include "utils.h"

#include <SDL3/SDL.h>
#include <stdio.h>
#include <string.h>

#include "helpers/logger.h"

#ifdef _WIN32
  #include <windows.h>
#elif __linux__
  #include <unistd.h>
#elif __APPLE__
  #include <mach-o/dyld.h>
#endif

double utils_get_scale(void) {
#ifdef _WIN32
  double scale = (double)SDL_GetDisplayContentScale(SDL_GetPrimaryDisplay());
  log_debug("utils: display content scale = %.2f", scale);
  return scale;
#else
  log_trace("utils: non-Windows platform, using fixed scale 1.0");
  return 1.0;
#endif
}

void utils_get_exe_filename(char *buf, int size) {
#ifdef _WIN32
  int len = GetModuleFileName(NULL, buf, size - 1);
  buf[len] = '\0';
#elif __linux__
  char path[512];
  snprintf(path, sizeof(path), "/proc/%d/exe", getpid());
  int len = (int)readlink(path, buf, size - 1);
  if (len < 0) {
    log_warn("utils: readlink(%s) failed, exe path unknown", path);
    len = 0;
  }
  buf[len] = '\0';
#elif __APPLE__
  unsigned sz = (unsigned)size;
  if (_NSGetExecutablePath(buf, &sz) != 0) {
    log_warn("utils: _NSGetExecutablePath buffer too small");
    buf[0] = '\0';
    return;
  }
  char resolved[2048];
  if (realpath(buf, resolved)) {
    strncpy(buf, resolved, size - 1);
    buf[size - 1] = '\0';
  }
#else
  log_warn("utils: unrecognized platform, falling back to relative path './cdin'");
  strncpy(buf, "./cdin", size - 1);
  buf[size - 1] = '\0';
#endif
  log_debug("utils: exe filename resolved to \"%s\"", buf);
}
