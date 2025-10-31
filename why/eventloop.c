#include <ev.h>
#include <stdlib.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

static const char* EVENT_LOOP_META = "lua_event_loop";

static void on_sigint(struct ev_loop* loop, ev_signal* w, int revents)
{
  /* Try to break out of the loop cleanly */
  ev_break(loop, EVBREAK_ALL);
  free(w);
}

static int eventloop_factory(lua_State* L)
{
  struct ev_loop** loop = lua_newuserdata(L, sizeof(struct ev_loop*));

  /* set its metatable */
  luaL_getmetatable(L, EVENT_LOOP_META);
  lua_setmetatable(L, -2);

  *loop = EV_DEFAULT;

  /* Set up sigint watcher */
  ev_signal* signal_watcher = malloc(sizeof(ev_signal));
  ev_signal_init(signal_watcher, on_sigint, SIGINT);
  ev_signal_start(*loop, signal_watcher);

  return 1;
}

static int eventloop_run(lua_State* L)
{
  struct ev_loop** loop = luaL_checkudata(L, 1, EVENT_LOOP_META);
  ev_run(*loop, 0);
  return 0;
}

static const struct luaL_Reg eventloop_methods[] = {
  {"run", eventloop_run},
  {NULL, NULL}
};

static const struct luaL_Reg eventloop_funcs[] = {
  {"new", eventloop_factory},
  {NULL, NULL}
};

static void create_class(
  lua_State* L,
  const char* meta,
  const struct luaL_Reg* methods
) {
  luaL_newmetatable(L, meta);
  luaL_setfuncs(L, methods, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
}

int luaopen_why_eventloop(lua_State* L)
{
  create_class(L, EVENT_LOOP_META, eventloop_methods);
  luaL_newlib(L, eventloop_funcs);
  return 1;
}

