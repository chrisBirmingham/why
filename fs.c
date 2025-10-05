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

static const char* DIR_META = "lua_directory";

static int fs_extname(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);
  char* copy = strdup(path);
  const char* base = basename(copy);

  const char* dot = strrchr(base, '.');
  if (!dot || dot == base) {
    lua_pushstring(L, "");
  }

  lua_pushstring(L, dot);
  free(copy);
  return 1;
}

static int fs_realpath(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);
  char* res = realpath(path, NULL);

  if (res == NULL) {
    luaL_error(L, "cannot realpath %s: %s", path, strerror(errno));
  }

  lua_pushstring(L, res);
  free(res);
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

static int dir_iter(lua_State* L)
{
  DIR* d = *(DIR**)lua_touserdata(L, lua_upvalueindex(1));
  struct dirent* entry;

  if ((entry = readdir(d)) != NULL) {
    lua_pushstring(L, entry->d_name);
    return 1;
  }

  return 0;
}
    
static int dir_factory(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);

  /* create a userdatum to store a DIR address */
  DIR** d = (DIR**)lua_newuserdata(L, sizeof(DIR*));

  /* set its metatable */
  luaL_getmetatable(L, DIR_META);
  lua_setmetatable(L, -2);

  /* try to open the given directory */
  *d = opendir(path);

  if (*d == NULL) {/* error opening the directory? */
    luaL_error(L, "cannot open %s: %s", path, strerror(errno));
  }

  lua_pushcclosure(L, dir_iter, 1);
  return 1;
}

static int dir_close(lua_State* L)
{
  DIR* d = *(DIR**)lua_touserdata(L, 1);

  if (d != NULL) {
    closedir(d);
  }

  return 0;
}

static const struct luaL_Reg dir_methods[] = {
  {"__close", dir_close},
  {"__gc", dir_close},
  {NULL, NULL}
};

static const struct luaL_Reg fs_funcs[] = {
  {"scandir", dir_factory},
  {"extname", fs_extname},
  {"is_dir", is_dir},
  {"realpath", fs_realpath},
  {NULL, NULL}
};

static void create_dir_meta(lua_State* L)
{
  luaL_newmetatable(L, DIR_META);
  luaL_setfuncs(L, dir_methods, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
}

int luaopen_fs(lua_State* L)
{
  create_dir_meta(L);
  luaL_newlib(L, fs_funcs);
  return 1;
}

