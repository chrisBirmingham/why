#include <ev.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

static const char* CLIENT_SOCKET_META = "lua_client_socket";
static const char* FUNC_INDEX = "SERVER_FUNC";

#define BUFFER_SIZE 512

static void on_sigint(struct ev_loop* loop, ev_signal* w, int revents)
{
  /* Try to break out of the loop cleanly */
  ev_break(loop, EVBREAK_ALL);
}

static void on_readable(struct ev_loop* loop, ev_io* w, int revents)
{
  lua_State* L = w->data;

  /* Get the server func out of the registry */
  lua_pushstring(L, FUNC_INDEX);
  lua_gettable(L, LUA_REGISTRYINDEX);

  /* Convert the fd into a userdata so lua can use it */
  int* fd = (int*)lua_newuserdata(L, sizeof(int));

  /* set its metatable */
  luaL_getmetatable(L, CLIENT_SOCKET_META);
  lua_setmetatable(L, -2);

  *fd = w->fd;

  lua_call(L, 1, 0);

  close(*fd);
  ev_io_stop(loop, w);
  free(w);
}

static void on_connection(struct ev_loop* loop, ev_io* w, int revents)
{
  struct sockaddr_in address;
  socklen_t addrlen = sizeof(address);
  int fd = accept(w->fd, (struct sockaddr *)&address, &addrlen);

  if (fd < 0) {
    return;
  }

  ev_io* watcher = malloc(sizeof(ev_io));
  watcher->data = w->data;

  ev_io_init(watcher, on_readable, fd, EV_READ);
  ev_io_start(loop, watcher);
}
    
static int socket_factory(lua_State* L)
{
  int port = luaL_checknumber(L, 1);
  luaL_checktype(L, 2, LUA_TFUNCTION);

  /* Store the callback in the global registry */
  lua_pushstring(L, FUNC_INDEX);
  lua_pushvalue(L, 2);
  lua_settable(L, LUA_REGISTRYINDEX);

  int fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);

  if (fd < 0) {
    luaL_error(L, "Failed to create socket: %s", strerror(errno));
  }

  struct sockaddr_in address;
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_port = htons(port);
  int res = bind(fd, (struct sockaddr*)&address, sizeof(address));

  if (res < 0) {
    luaL_error(L, "Failed to bind to socket: %s", strerror(errno));
  }

  res = listen(fd, 10);

  if (res < 0) {
    luaL_error(L, "Faled to listen to socket: %s", strerror(errno));
  }

  struct ev_loop* loop = EV_DEFAULT;
 
  /* Set up server watcher */
  ev_io* w = malloc(sizeof(ev_io));
  w->data = L;
  ev_io_init(w, on_connection, fd, EV_READ);
  ev_io_start(loop, w);

  /* Set up sigint watcher */
  ev_signal signal_watcher;
  ev_signal_init(&signal_watcher, on_sigint, SIGINT);
  ev_signal_start(loop, &signal_watcher);

  ev_run(loop, 0);

  close(fd);

  return 0;
}

static int client_recv(lua_State* L)
{
  int* fd = (int*)luaL_checkudata(L, 1, CLIENT_SOCKET_META);
  luaL_Buffer buf;
  luaL_buffinit(L, &buf);
  ssize_t bytes;

  do {
    char buffer[BUFFER_SIZE];
    bytes = recv(*fd, buffer, BUFFER_SIZE, 0);

    if (bytes < 0) {
      luaL_error(L, "Failed to read new connection: %s", strerror(errno));
    }

    luaL_addlstring(&buf, buffer, bytes);
  } while (bytes == BUFFER_SIZE);

  luaL_pushresult(&buf);
  return 1;
}

static int client_send(lua_State* L)
{
  int* fd = (int*)luaL_checkudata(L, 1, CLIENT_SOCKET_META);
  const char* buffer = luaL_checkstring(L, 2);
  lua_Integer len = luaL_len(L, 2);

  if (len == 0) {
    return 0;
  }

  size_t written = 0;
  size_t left = len;

  while (written < len) {
    int n = write(*fd, buffer + written, left);

    if (n < 0) {
      luaL_error(L, "Failed to send packet: %s", strerror(errno));
    }
    written += n;
    left -= n;
  }
  
  return 0;
}

static const struct luaL_Reg client_socket_methods[] = {
  {"recv", client_recv},
  {"send", client_send},
  {NULL, NULL}
};

static const struct luaL_Reg server_funcs[] = {
  {"listen", socket_factory},
  {NULL, NULL}
};

static void create_client_socket_meta(lua_State* L)
{
  luaL_newmetatable(L, CLIENT_SOCKET_META);
  luaL_setfuncs(L, client_socket_methods, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
}

int luaopen_server(lua_State* L)
{
  create_client_socket_meta(L);
  luaL_newlib(L, server_funcs);
  return 1;
}

