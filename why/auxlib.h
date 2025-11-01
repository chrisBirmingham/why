#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

struct luaL_Const {
  const char* name;
  int value;
};

inline void create_constant(lua_State* L, const char* key, int value)
{
  lua_pushstring(L, key);
  lua_pushinteger(L, value);
  lua_settable(L, -3);
}

inline void create_constants(lua_State* L, const struct luaL_Const* consts)
{
  for (; consts->name != NULL; consts++) {
    create_constant(L, consts->name, consts->value);
  }
}

inline void create_class(
  lua_State* L,
  const char* meta,
  const struct luaL_Reg* methods
) {
  luaL_newmetatable(L, meta);
  luaL_setfuncs(L, methods, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
}

