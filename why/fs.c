#define _DEFAULT_SOURCE

#include <dirent.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <libgen.h>

static int fs_fnparts(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);
  char* copy = strdup(path);
  const char* base = basename(copy);
  lua_pushstring(L, base);
  const char* dot = strrchr(base, '.');

  if (dot == NULL || dot == base) {
    lua_pushstring(L, "");
  } else {
    lua_pushstring(L, dot);
  }

  free(copy);
  return 2;
}

static int fs_exist(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);
  struct stat buffer;
  lua_pushboolean(L, stat(path, &buffer) == 0);
  return 1;
}

static int fs_mtime(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);
  struct stat buffer;

  if (stat(path, &buffer) < 0) {
    luaL_error(L, "cannot stat %s: %s", path, strerror(errno));
  }

  lua_pushinteger(L, buffer.st_mtime);
  return 1;
}

static int is_dir(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);
  struct stat buffer;
  int status = stat(path, &buffer);

  if (status < 0) {
    luaL_error(L, "cannot stat %s: %s", path, strerror(errno));
  }

  lua_pushboolean(L, S_ISDIR(buffer.st_mode));
  return 1;
}

static inline int strmatch(
  const char* restrict lhs,
  const char* restrict rhs
) {
  return strcmp(lhs, rhs) == 0;
}

static inline int filter(const struct dirent* item)
{
  const char* name = item->d_name;
  return (!strmatch(name, ".") && !strmatch(name, ".."));
}

static int fs_scandir(lua_State* L)
{
  size_t len;
  const char* directory = luaL_checklstring(L, 1, &len);
  struct dirent** namelist;

  const char* slash = (directory[len - 1] == '/')? "": "/";
  int res = scandir(directory, &namelist, filter, alphasort);

  if (res < 0) {
    luaL_error(L, "couldn't scandir %s: %s", directory, strerror(errno));
  }

  lua_newtable(L);

  for (unsigned int i = 0; i < res; i++) {
    lua_pushfstring(L, "%s%s%s", directory, slash, namelist[i]->d_name);
    lua_rawseti(L, -2, i + 1);
    free(namelist[i]);
  }

  free(namelist);
  return 1;
}

static const struct luaL_Reg fs_funcs[] = {
  {"exist", fs_exist},
  {"mtime", fs_mtime},
  {"fnparts", fs_fnparts},
  {"scandir", fs_scandir},
  {"is_dir", is_dir},
  {NULL, NULL}
};

int luaopen_why_fs(lua_State* L)
{
  luaL_newlib(L, fs_funcs);
  return 1;
}

