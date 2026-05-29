/* This file is just a central place to define global constants.*/
#include "global_config.h"
const char *CDIN_APP_NAME    = "cdin";
const char *CDIN_APP_VERSION =
#ifdef CDIN_VERSION
  CDIN_VERSION;
#else
  "0.0.0-dev";
#endif

const char *CDIN_APP_COMMIT =
#ifdef CDIN_COMMIT
  CDIN_COMMIT;
#else
  "unknown";
#endif
