#ifndef FS_OPS_H
#define FS_OPS_H
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#define FS_PATH_MAX 4096

#ifdef _WIN32
#  define FS_SEP '\\'
#else
#  define FS_SEP '/'
#endif
int fs_path_exists(const char *path);
int fs_is_dir(const char *path);
int luaopen_fs(lua_State *L);

#endif /* FS_OPS_H */