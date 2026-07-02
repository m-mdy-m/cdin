#include "initial.h"

#include "helpers/logger.h"

#ifdef _WIN32
  #include <windows.h>
#endif

void cdin_init_setup(void) {
#ifdef _WIN32
  log_debug("initial: requesting Windows DPI awareness");
  HINSTANCE lib = LoadLibrary("user32.dll");
  if (lib) {
    typedef int (*DPIFunc)(void);
    DPIFunc fn = (DPIFunc)(void *)GetProcAddress(lib, "SetProcessDPIAware");
    if (fn) {
      fn();
      log_debug("initial: SetProcessDPIAware() called");
    } else {
      log_warn("initial: SetProcessDPIAware not found in user32.dll");
    }
    FreeLibrary(lib);
  } else {
    log_warn("initial: failed to load user32.dll for DPI awareness setup");
  }
#else
  /* Nothing needed on Unit -- SDL3 handles it. */
  log_trace("initial: no platform-specific setup needed (non-Windows)");
#endif
}