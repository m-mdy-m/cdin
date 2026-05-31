#include "utils.h"

#include <SDL3/SDL.h>
#include <stdio.h>
#include <string.h>

#ifdef _WIN32
  #include <windows.h>
#elif __linux__
  #include <unistd.h>
#elif __APPLE__
  #include <mach-o/dyld.h>
#endif

double utils_get_scale(void) {
#ifdef _WIN32
  return (double)SDL_GetDisplayContentScale(SDL_GetPrimaryDisplay());
#else
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
  if (len < 0) len = 0;
  buf[len] = '\0';
#elif __APPLE__
  unsigned sz = (unsigned)size;
  _NSGetExecutablePath(buf, &sz);
#else
  strncpy(buf, "./cdin", size - 1);
  buf[size - 1] = '\0';
#endif
}