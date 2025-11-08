#include <ev.h>
#include <stdlib.h>
#include "auxlib.h"

static const char* EVENT_LOOP_META = "lua_event_loop";
static const char* EVENT_META = "lua_event";

static void set_callback(lua_State* L, void* udata, int index)
{
  lua_pushlightuserdata(L, udata);
  lua_pushvalue(L, index);
  lua_settable(L, LUA_REGISTRYINDEX);
}

static inline void get_callback(lua_State* L, void* udata)
{
  lua_pushlightuserdata(L, udata);
  lua_gettable(L, LUA_REGISTRYINDEX);
}

static void on_signal(struct ev_loop* loop, ev_signal* w, int revents)
{
  lua_State* L = w->data;
  get_callback(L, w);
  lua_call(L, 0, 0);
}

static void on_io(struct ev_loop* loop, ev_io* w, int revents)
{
  lua_State* L = w->data;
  get_callback(L, w);

  ev_io** event = create_instance(L, EVENT_META, sizeof(w));
  *event = w;

  int* conn = create_instance(L, "lua_socket", sizeof(w->fd));
  *conn = w->fd;

  lua_call(L, 2, 0);
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

  ev_signal* signal_watcher = malloc(sizeof(ev_signal));
  signal_watcher->data = L;

  set_callback(L, signal_watcher, 3);

  ev_signal_init(signal_watcher, on_signal, signal);
  ev_signal_start(*loop, signal_watcher);

  return 0;
}

static int eventloop_io(lua_State* L)
{
  struct ev_loop** loop = luaL_checkudata(L, 1, EVENT_LOOP_META);
  int fd = luaL_checkinteger(L, 2);
  int event_type = luaL_checkinteger(L, 3);
  luaL_checktype(L, 4, LUA_TFUNCTION);

  ev_io* watcher = malloc(sizeof(ev_io));
  watcher->data = L;

  set_callback(L, watcher, 4);

  ev_io_init(watcher, on_io, fd, event_type);
  ev_io_start(*loop, watcher);

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

static int event_stop(lua_State* L)
{
  struct ev_io** w = luaL_checkudata(L, 1, EVENT_META);
  struct ev_loop** loop = luaL_checkudata(L, 2, EVENT_LOOP_META);
  ev_io_stop(*loop, *w);
  free(*w);
  return 0;
}

static const struct luaL_Reg event_methods[] = {
  {"stop", event_stop},
  {NULL, NULL}
};

static const struct luaL_Reg eventloop_methods[] = {
  {"run", eventloop_run},
  {"signal", eventloop_signal},
  {"io", eventloop_io},
  {"stop", eventloop_stop},
  {NULL, NULL}
};

static const struct luaL_Reg eventloop_funcs[] = {
  {"eventloop", eventloop_factory},
  {NULL, NULL}
};

static const struct luaL_Const eventloop_constants[] = {
  {"SIGTERM", SIGTERM},
  {"SIGINT", SIGINT},
  {"SIGHUP", SIGHUP},
  {"EV_WRITE", EV_WRITE},
  {"EV_READ", EV_READ},
  {NULL, 0}
};

int luaopen_why_event(lua_State* L)
{
  create_class(L, EVENT_LOOP_META, eventloop_methods);
  create_class(L, EVENT_META, event_methods);
  luaL_newlib(L, eventloop_funcs);
  create_constants(L, eventloop_constants);
  return 1;
}

