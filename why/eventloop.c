#include <ev.h>
#include <stdlib.h>
#include "auxlib.h"

static const char* EVENT_LOOP_META = "lua_event_loop";

static void on_signal(struct ev_loop*, ev_signal* w, int revents)
{
  lua_State* L = w->data;

  lua_pushinteger(L, w->signum);
  lua_gettable(L, LUA_REGISTRYINDEX);

  lua_call(L, 0, 0);
}

static int eventloop_factory(lua_State* L)
{
  struct ev_loop** loop = create_instance(L, EVENT_LOOP_META, sizeof(struct ev_loop*));
  *loop = EV_DEFAULT;
  return 1;
}

static int eventloop_signal(lua_State* L)
{
  struct ev_loop** loop = luaL_checkudata(L, 1, EVENT_LOOP_META);
  int signal = luaL_checkinteger(L, 2);
  luaL_checktype(L, 3, LUA_TFUNCTION);

  lua_pushinteger(L, signal);
  lua_pushvalue(L, 3);
  lua_settable(L, LUA_REGISTRYINDEX);

  ev_signal* signal_watcher = malloc(sizeof(ev_signal));
  signal_watcher->data = L;
  ev_signal_init(signal_watcher, on_signal, signal);
  ev_signal_start(*loop, signal_watcher);

  return 0;
}

static int eventloop_run(lua_State* L)
{
  struct ev_loop** loop = luaL_checkudata(L, 1, EVENT_LOOP_META);
  ev_run(*loop, 0);
  return 0;
}

static int eventloop_stop(lua_State* L)
{
  struct ev_loop** loop = luaL_checkudata(L, 1, EVENT_LOOP_META);
  ev_break(*loop, EVBREAK_ALL);
  return 0;
}

static const struct luaL_Reg eventloop_methods[] = {
  {"run", eventloop_run},
  {"signal", eventloop_signal},
  {"stop", eventloop_stop},
  {NULL, NULL}
};

static const struct luaL_Reg eventloop_funcs[] = {
  {"new", eventloop_factory},
  {NULL, NULL}
};

static const struct luaL_Const eventloop_constants[] = {
  {"SIGTERM", SIGTERM},
  {"SIGINT", SIGINT},
  {"SIGHUP", SIGHUP},
  {NULL, 0}
};

int luaopen_why_eventloop(lua_State* L)
{
  create_class(L, EVENT_LOOP_META, eventloop_methods);
  luaL_newlib(L, eventloop_funcs);
  create_constants(L, eventloop_constants);
  return 1;
}

