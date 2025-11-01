#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

inline void create_const(lua_State* L, const char* key, int value)
{
  lua_pushstring(L, key);
  lua_pushinteger(L, value);
  lua_settable(L, -3);
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

