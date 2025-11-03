#include <ev.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <sys/un.h>
#include <unistd.h>
#include "auxlib.h"

static const char* SOCKET_META = "lua_socket";
static const int CONNECT = 0;
static const int BIND = 1;

#define BUFFER_SIZE 512

static inline int* create_socket_udata(lua_State* L, const char* meta, int fd)
{
  /* Convert the fd into a userdata so lua can use it */
  int* conn = create_instance(L, meta, sizeof(fd));
  *conn = fd;
  return conn;
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

static int socket_accept(lua_State* L)
{
  int* sock = luaL_checkudata(L, 1, SOCKET_META);
  struct sockaddr_in address;
  socklen_t addrlen = sizeof(address);
  int fd = accept(*sock, (struct sockaddr *)&address, &addrlen);
  lua_pushinteger(L, fd);
  return 1;
}

static int socket_fd(lua_State* L)
{
  int* fd = luaL_checkudata(L, 1, SOCKET_META);
  lua_pushinteger(L, *fd);
  return 1;
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

static const struct luaL_Reg socket_methods[] = {
  {"listen", socket_listen},
  {"accept", socket_accept},
  {"recv", socket_recv},
  {"send", socket_send},
  {"fd", socket_fd},
  {"close", socket_close},
  {NULL, NULL}
};

static const struct luaL_Reg socket_funcs[] = {
  {"tcp", socket_tcp_factory},
  {"unix", socket_unix_factory},
  {NULL, NULL}
};

static const struct luaL_Const socket_constants[] = {
  {"SOCK_STREAM", SOCK_STREAM},
  {"SOCK_DGRAM", SOCK_DGRAM},
  {"CONNECT", CONNECT},
  {"BIND", BIND},
  {NULL, 0}
};

int luaopen_why_socket(lua_State* L)
{
  create_class(L, SOCKET_META, socket_methods);
  luaL_newlib(L, socket_funcs);
  create_constants(L, socket_constants);
  return 1;
}

