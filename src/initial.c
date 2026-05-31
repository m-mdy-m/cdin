#include "initial.h"

#ifdef _WIN32
  #include <windows.h>
#endif

void cdin_init_setup(void) {
#ifdef _WIN32
  HINSTANCE lib = LoadLibrary("user32.dll");
  if (lib) {
    typedef int (*DPIFunc)(void);
    DPIFunc fn = (DPIFunc)(void *)GetProcAddress(lib, "SetProcessDPIAware");
    if (fn) fn();
    FreeLibrary(lib);
  }
#endif
  /* Nothing needed on Linux/macOS — SDL3 handles it */
}