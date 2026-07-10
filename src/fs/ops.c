#include "ops.h"

#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#ifndef _WIN32
#  include <unistd.h>
#else
#  include <windows.h>
#  include <direct.h>
#  include <io.h>
#endif

#ifdef _WIN32
#  define FS_MKDIR(p)  _mkdir(p)
#  define FS_RMDIR(p)  _rmdir(p)
#  define FS_UNLINK(p) _unlink(p)
#else
#  define FS_MKDIR(p)  mkdir((p), 0755)
#  define FS_RMDIR(p)  rmdir(p)
#  define FS_UNLINK(p) unlink(p)
#endif

int fs_is_dir(const char *path) {
  struct stat st;
  if (stat(path, &st) != 0) return 0;
  return S_ISDIR(st.st_mode) ? 1 : 0;
}

int fs_path_exists(const char *path) {
  struct stat st;
  return stat(path, &st) == 0;
}
static int mkdir_all_r(char *buf) {
  size_t len = strlen(buf);
  for (size_t i = 1; i < len; i++) {
    if (buf[i] == '/' || buf[i] == '\\') {
      char saved = buf[i];
      buf[i] = '\0';
      if (buf[0] != '\0' && FS_MKDIR(buf) != 0 && errno != EEXIST) {
        buf[i] = saved;
        return -1;
      }
      buf[i] = saved;
    }
  }
  if (FS_MKDIR(buf) != 0 && errno != EEXIST) return -1;
  return 0;
}

static int remove_all_r(const char *path) {
  if (!fs_is_dir(path))
    return FS_UNLINK(path);

  DIR *d = opendir(path);
  if (!d) return -1;

  struct dirent *entry;
  int failed = 0;
  while ((entry = readdir(d))) {
    if (strcmp(entry->d_name, ".")  == 0) continue;
    if (strcmp(entry->d_name, "..") == 0) continue;

    char child[FS_PATH_MAX];
    int n = snprintf(child, sizeof(child), "%s%c%s",
                     path, FS_SEP, entry->d_name);
    if (n < 0 || (size_t)n >= sizeof(child)) { failed = 1; break; }
    if (remove_all_r(child) != 0)            { failed = 1; break; }
  }
  closedir(d);
  if (failed) return -1;
  return FS_RMDIR(path);
}

static int copy_one_file(const char *src, const char *dst) {
  FILE *in = fopen(src, "rb");
  if (!in) return -1;

  FILE *out = fopen(dst, "wb");
  if (!out) { fclose(in); return -1; }

  char buf[65536];
  size_t n;
  int ok = 1;
  while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
    if (fwrite(buf, 1, n, out) != n) { ok = 0; break; }
  }
  if (ferror(in)) ok = 0;

  fclose(in);
  fclose(out);
  return ok ? 0 : -1;
}

static int copy_all_r(const char *src, const char *dst) {
  if (!fs_is_dir(src))
    return copy_one_file(src, dst);

  if (!fs_path_exists(dst) && FS_MKDIR(dst) != 0 && errno != EEXIST)
    return -1;

  DIR *d = opendir(src);
  if (!d) return -1;

  struct dirent *entry;
  int failed = 0;
  while ((entry = readdir(d))) {
    if (strcmp(entry->d_name, ".")  == 0) continue;
    if (strcmp(entry->d_name, "..") == 0) continue;

    char child_src[FS_PATH_MAX], child_dst[FS_PATH_MAX];
    int n1 = snprintf(child_src, sizeof(child_src), "%s%c%s",
                      src, FS_SEP, entry->d_name);
    int n2 = snprintf(child_dst, sizeof(child_dst), "%s%c%s",
                      dst, FS_SEP, entry->d_name);
    if (n1 < 0 || (size_t)n1 >= sizeof(child_src) ||
        n2 < 0 || (size_t)n2 >= sizeof(child_dst)) { failed = 1; break; }
    if (copy_all_r(child_src, child_dst) != 0)      { failed = 1; break; }
  }
  closedir(d);
  return failed ? -1 : 0;
}

static int f_mkdir_all(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  size_t len = strlen(path);
  if (len == 0 || len >= FS_PATH_MAX) {
    lua_pushnil(L);
    lua_pushstring(L, "mkdir_all: path too long or empty");
    return 2;
  }
  char buf[FS_PATH_MAX];
  memcpy(buf, path, len + 1);
  if (mkdir_all_r(buf) != 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_pushboolean(L, 1);
  return 1;
}

static int f_remove_all(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  if (!fs_path_exists(path)) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(ENOENT));
    return 2;
  }
  if (remove_all_r(path) != 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_pushboolean(L, 1);
  return 1;
}

static int f_copy_all(lua_State *L) {
  const char *src = luaL_checkstring(L, 1);
  const char *dst = luaL_checkstring(L, 2);
  if (!fs_path_exists(src)) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(ENOENT));
    return 2;
  }
  if (copy_all_r(src, dst) != 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_pushboolean(L, 1);
  return 1;
}

static int f_stat(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  struct stat st;
  if (stat(path, &st) != 0) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_newtable(L);

  if      (S_ISREG(st.st_mode)) lua_pushstring(L, "file");
  else if (S_ISDIR(st.st_mode)) lua_pushstring(L, "dir");
  else                           lua_pushstring(L, "other");
  lua_setfield(L, -2, "type");

  lua_pushnumber(L, (lua_Number)st.st_size);
  lua_setfield(L, -2, "size");

  lua_pushnumber(L, (lua_Number)st.st_mtime);
  lua_setfield(L, -2, "mtime");

  return 1;
}

static int f_list_dir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  DIR *d = opendir(path);
  if (!d) {
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    return 2;
  }
  lua_newtable(L);
  int i = 1;
  struct dirent *entry;
  while ((entry = readdir(d))) {
    if (strcmp(entry->d_name, ".")  == 0) continue;
    if (strcmp(entry->d_name, "..") == 0) continue;
    lua_pushstring(L, entry->d_name);
    lua_rawseti(L, -2, i++);
  }
  closedir(d);
  return 1;
}

static const luaL_Reg lib[] = {
  { "mkdir_all",  f_mkdir_all  },
  { "remove_all", f_remove_all },
  { "copy_all",   f_copy_all   },
  { "stat",       f_stat       },
  { "list_dir",   f_list_dir   },
  { NULL, NULL }
};

int luaopen_fs(lua_State *L) {
  luaL_newlib(L, lib);
  return 1;
}
