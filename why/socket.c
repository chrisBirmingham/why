#include <ev.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <sys/un.h>
#include <unistd.h>
#include "auxlib.h"

static const char* SOCKET_META = "lua_socket";
static const char* CLIENT_SOCKET_META = "lua_client_socket";
static const char* EVENT_LOOP_META = "lua_event_loop";
static const char* FUNC_INDEX = "SERVER_FUNC";

static const int CONNECT = 0;
static const int BIND = 1;

#define BUFFER_SIZE 512

static int* create_socket_udata(lua_State* L, const char* meta, int fd)
{
  /* Convert the fd into a userdata so lua can use it */
  int* conn = lua_newuserdata(L, sizeof(int));

  /* set its metatable */
  luaL_getmetatable(L, meta);
  lua_setmetatable(L, -2);

  *conn = fd;
  return conn;
}

static void on_readable(struct ev_loop* loop, ev_io* w, int revents)
{
  lua_State* L = w->data;

  /* Get the server func out of the registry */
  lua_pushstring(L, FUNC_INDEX);
  lua_gettable(L, LUA_REGISTRYINDEX);

  int* fd = create_socket_udata(L, CLIENT_SOCKET_META, w->fd);

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

static int socket_connect(int fd, int conn_type, struct sockaddr* addr, socklen_t len)
{
  if (conn_type) {
    return bind(fd, addr, len);
  }

  return connect(fd, addr, len);
}

static int socket_tcp_factory(lua_State* L)
{
  int port = luaL_checkinteger(L, 1);
  int type = luaL_optinteger(L, 2, SOCK_STREAM);
  int conn_type = luaL_optinteger(L, 3, BIND);

  int fd = socket(AF_INET, type | SOCK_NONBLOCK, 0);

  if (fd < 0) {
    luaL_error(L, "Failed to create socket: %s", strerror(errno));
  }

  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = INADDR_ANY;
  addr.sin_port = htons(port);

  int res = socket_connect(fd, conn_type, (struct sockaddr*)&addr, sizeof(addr));

  if (res < 0) {
    luaL_error(L, "Failed to bind to socket: %s", strerror(errno));
  }

  create_socket_udata(L, SOCKET_META, fd);

  return 1;
}

static int socket_unix_factory(lua_State* L)
{
  const char* path = luaL_checkstring(L, 1);
  int type = luaL_optinteger(L, 2, SOCK_STREAM);
  int conn_type = luaL_optinteger(L, 3, BIND);

  int fd = socket(AF_UNIX, type | SOCK_NONBLOCK, 0);

  if (fd < 0) {
    luaL_error(L, "Failed to create socket: %s", strerror(errno));
  }

  struct sockaddr_un addr;
  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path, path);

  int res = socket_connect(fd, conn_type, (struct sockaddr*)&addr, sizeof(addr));

  if (res < 0) {
    luaL_error(L, "Failed to bind to socket: %s", strerror(errno));
  }

  create_socket_udata(L, SOCKET_META, fd);

  return 1;
}

static int socket_listen(lua_State* L)
{
  int* fd = luaL_checkudata(L, 1, SOCKET_META);
  int backlog = luaL_checkinteger(L, 2);

  if (listen(*fd, backlog) < 0) {
    luaL_error(L, "Faled to listen to socket: %s", strerror(errno));
  }

  return 0;
}

static int socket_onconnect(lua_State* L)
{
  int* fd = luaL_checkudata(L, 1, SOCKET_META);
  struct ev_loop** loop = luaL_checkudata(L, 2, EVENT_LOOP_META);
  luaL_checktype(L, 3, LUA_TFUNCTION);

  /* Store the callback in the global registry */
  lua_pushstring(L, FUNC_INDEX);
  lua_pushvalue(L, 3);
  lua_settable(L, LUA_REGISTRYINDEX);
 
  /* Set up server watcher */
  ev_io* w = malloc(sizeof(ev_io));
  w->data = L;
  ev_io_init(w, on_connection, *fd, EV_READ);
  ev_io_start(*loop, w);
  return 0;
}

static int socket_close(lua_State* L)
{
  int* fd = luaL_checkudata(L, 1, SOCKET_META);
  close(*fd);
  return 0;
}

static int socket_recv(lua_State* L)
{
  int* fd = lua_touserdata(L, 1);
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

static int socket_send(lua_State* L)
{
  int* fd = lua_touserdata(L, 1);
  size_t len;
  const char* buffer = luaL_checklstring(L, 2, &len);

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
  {"recv", socket_recv},
  {"send", socket_send},
  {NULL, NULL}
};

static const struct luaL_Reg socket_methods[] = {
  {"listen", socket_listen},
  {"onconnect", socket_onconnect},
  {"recv", socket_recv},
  {"send", socket_send},
  {"close", socket_close},
  {NULL, NULL}
};

static const struct luaL_Reg socket_funcs[] = {
  {"tcp", socket_tcp_factory},
  {"unix", socket_unix_factory},
  {NULL, NULL}
};

int luaopen_why_socket(lua_State* L)
{
  create_class(L, CLIENT_SOCKET_META, client_socket_methods);
  create_class(L, SOCKET_META, socket_methods);
  luaL_newlib(L, socket_funcs);
  create_const(L, "SOCK_STREAM", SOCK_STREAM);
  create_const(L, "SOCK_DGRAM", SOCK_DGRAM);
  create_const(L, "CONNECT", CONNECT);
  create_const(L, "BIND", BIND);
  return 1;
}

