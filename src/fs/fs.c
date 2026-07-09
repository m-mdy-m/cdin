#include "fs.h"
#include "../core/logger.h"

#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <dirent.h>

#ifndef _WIN32
  #include <unistd.h>
#else
  #include <windows.h>
  #include <direct.h>
  #define realpath(x, y) _fullpath(y, x, MAX_PATH)
#endif


static int f_chdir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
#ifdef _WIN32
  if (_chdir(path) != 0) {
    log_error("fs.chdir(\"%s\") failed: %s", path, strerror(errno));
    luaL_error(L, "chdir() failed: %s", strerror(errno));
  }
#else
  if (chdir(path) != 0) {
    log_error("fs.chdir(\"%s\") failed: %s", path, strerror(errno));
    luaL_error(L, "chdir() failed: %s", strerror(errno));
  }
#endif
  log_info("fs: working directory changed to \"%s\"", path);
  return 0;
}


static int f_list_dir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  DIR *dir = opendir(path);
  if (!dir) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_newtable(L);
  int i = 1;
  struct dirent *entry;
  while ((entry = readdir(dir))) {
    if (strcmp(entry->d_name, ".")  == 0) continue;
    if (strcmp(entry->d_name, "..") == 0) continue;
    lua_pushstring(L, entry->d_name);
    lua_rawseti(L, -2, i++);
  }
  closedir(dir);
  return 1;
}


static int f_absolute_path(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  char *res = realpath(path, NULL);
  if (!res) return 0;
  lua_pushstring(L, res);
  free(res);
  return 1;
}


static int f_get_file_info(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  struct stat s;
  if (stat(path, &s) < 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_newtable(L);
  lua_pushnumber(L, (lua_Number)s.st_mtime);
  lua_setfield(L, -2, "modified");
  lua_pushnumber(L, (lua_Number)s.st_size);
  lua_setfield(L, -2, "size");
  if      (S_ISREG(s.st_mode)) lua_pushstring(L, "file");
  else if (S_ISDIR(s.st_mode)) lua_pushstring(L, "dir");
  else                          lua_pushnil(L);
  lua_setfield(L, -2, "type");
  return 1;
}


static const luaL_Reg lib[] = {
  { "chdir",         f_chdir         },
  { "list_dir",      f_list_dir      },
  { "absolute_path", f_absolute_path },
  { "get_file_info", f_get_file_info },
  { NULL, NULL }
};

int luaopen_fs(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}