#include <magic.h>
#include "auxlib.h"

static const char* MAGIC_META = "lua_magic";

static int magic_factory(lua_State* L)
{
  magic_t cookie = magic_open(MAGIC_MIME_TYPE);

  if (cookie == NULL) {
    luaL_error(L, "Failed to create magic instance"); 
  }

  if (magic_load(cookie, NULL) < 0) {
    magic_close(cookie);
    luaL_error(L, "Failed to open magic database: %s", magic_error(cookie));
  }

  magic_t* c = (magic_t*)lua_newuserdata(L, sizeof(magic_t*));

  /* set its metatable */
  luaL_getmetatable(L, MAGIC_META);
  lua_setmetatable(L, -2);

  *c = cookie;

  return 1;
}
    
static int magic_detect(lua_State* L)
{
  magic_t* cookie = (magic_t*)luaL_checkudata(L, 1, MAGIC_META);
  const char* path = luaL_checkstring(L, 2);
  const char* type = magic_file(*cookie, path);

  if (type == NULL) {
    luaL_error(L, "Failed to detect file mimetype: %s", magic_error(*cookie));
  }

  lua_pushstring(L, type);
  return 1;
}

static int magic_destruct(lua_State* L)
{
  magic_t* cookie = (magic_t*)luaL_checkudata(L, 1, MAGIC_META);

  if (cookie != NULL) {
    magic_close(*cookie);
  }

  return 0;
}

static const struct luaL_Reg magic_methods[] = {
  {"detect", magic_detect},
  {"__gc", magic_destruct},
  {"__close", magic_destruct},
  {NULL, NULL}
};

static const struct luaL_Reg magic_funcs[] = {
  {"open", magic_factory},
  {NULL, NULL}
};

int luaopen_why_mimetype(lua_State* L)
{
  create_class(L, MAGIC_META, magic_methods);
  luaL_newlib(L, magic_funcs);
  return 1;
}

