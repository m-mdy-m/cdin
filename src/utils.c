static void get_exee_filename(char *buf, int size){
#if _WIN32
  int len = GetModuleFileName(NULL, buf, sz - 1);
  buf[len] = '\0';
#elif __linux__
  char path[512];
  sprintf(path, "/proc/%d/exe", getpid());
  int len = readlink(path, buf, sz - 1);
  buf[len] = '\0';
#elif __APPLE__
  unsigned size = sz;
  _NSGetExecutablePath(buf, &size);
#else
  strcpy(buf, "./cdin");
#endif
}
static double get_scale(void) {
  float dpi;
  SDL_GetDisplayDPI(0, NULL, &dpi, NULL);
#if _WIN32
  return dpi / 96.0;
#else
  return 1.0;
#endif
}