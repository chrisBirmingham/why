#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

static const char* SOCKET_META = "lua_socket";
static const char* CLIENT_SOCKET_META = "lua_client_socket";

#define BUFFER_SIZE 512
    
static int socket_factory(lua_State* L)
{
  int port = luaL_checknumber(L, 1);
  int* fd = (int*)lua_newuserdata(L, sizeof(int));

  /* set its metatable */
  luaL_getmetatable(L, SOCKET_META);
  lua_setmetatable(L, -2);

  *fd = socket(AF_INET, SOCK_STREAM, 0);

  if (*fd < 0) {
    luaL_error(L, "Failed to create socket: %s", strerror(errno));
  }

  struct sockaddr_in address;
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_port = htons(port);
  int res = bind(*fd, (struct sockaddr*)&address, sizeof(address));

  if (res < 0) {
    luaL_error(L, "Failed to bind to socket: %s", strerror(errno));
  }

  res = listen(*fd, 10);

  if (res < 0) {
    luaL_error(L, "Faled to listen to socket: %s", strerror(errno));
  }

  return 1;
}

static int socket_accept(lua_State* L)
{
  int* fd = (int*)lua_touserdata(L, 1);
  int* client_fd = (int*)lua_newuserdata(L, sizeof(int));

  /* set its metatable */
  luaL_getmetatable(L, CLIENT_SOCKET_META);
  lua_setmetatable(L, -2);

  struct sockaddr_in address;
  socklen_t addrlen = sizeof(address);
  *client_fd = accept(*fd, (struct sockaddr *)&address, &addrlen);

  if (*client_fd < 0) {
    luaL_error(L, "Failed to accept new connection: %s", strerror(errno));
  }

  return 1;
}

static int client_recv(lua_State* L)
{
  int* fd = (int*)lua_touserdata(L, 1);
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
  int* fd = (int*)lua_touserdata(L, 1);
  const char* buffer = luaL_checkstring(L, 2);
  lua_Integer len = luaL_len(L, 2);

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

static int socket_close(lua_State* L)
{
  int* fd = (int*)lua_touserdata(L, 1);

  if (fd != NULL) {
    close(*fd);
  }

  return 0;
}

static const struct luaL_Reg client_socket_methods[] = {
  {"recv", client_recv},
  {"send", client_send},
  {"close", socket_close}
};

static const struct luaL_Reg socket_methods[] = {
  {"accept", socket_accept},
  {"__close", socket_close},
  {"__gc", socket_close},
  {NULL, NULL}
};

static const struct luaL_Reg server_funcs[] = {
  {"bind", socket_factory},
  {NULL, NULL}
};

static void create_client_socket_meta(lua_State* L)
{
  luaL_newmetatable(L, CLIENT_SOCKET_META);
  luaL_setfuncs(L, client_socket_methods, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
}

static void create_socket_meta(lua_State* L)
{
  luaL_newmetatable(L, SOCKET_META);
  luaL_setfuncs(L, socket_methods, 0);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
}

int luaopen_server(lua_State* L)
{
  create_client_socket_meta(L);
  create_socket_meta(L);
  luaL_newlib(L, server_funcs);
  return 1;
}

