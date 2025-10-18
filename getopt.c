#include <getopt.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>

extern char* optarg;
extern int optind;
extern int optopt;
extern int opterr;

static int lua_getopt(lua_State* L)
{
  const char* optstring = luaL_checkstring(L, 1);

  lua_getglobal(L, "arg");

  /* Plus one because progname is at 0 at not counted as part of len */
  unsigned int argc = luaL_len(L, -1) + 1;
  char** argv = malloc(argc * sizeof(char*) + 1);
  argv[argc] = NULL; 

  /* Convert global arg table to c array for getopt */
  for (unsigned int i = 0; i < argc; i++) {
    lua_pushinteger(L, i);
    lua_gettable(L, 2);
    argv[i] = (char*)lua_tostring(L, -1);
  }

  int c = 0;
  opterr = 0;

  lua_newtable(L);
  while ((c = getopt(argc, argv, optstring)) != -1) {
    if (c == '?') {
      if (strchr(optstring, optopt)) {
        luaL_error(L, "Option -%c requires an argument", optopt);
      }

      luaL_error(L, "Unknown option -%c", optopt);
    }

    const char opt[2] = {c, '\0'};

    if (optarg) {
      lua_pushstring(L, optarg);
    } else {
      lua_pushboolean(L, 1);
    }

    lua_setfield(L, -2, opt);
  }

  lua_newtable(L);
  for (unsigned int pos = 1; optind < argc;) {
    lua_pushstring(L, argv[optind++]);
    lua_seti(L, -2, pos++);
  }

  /* Clean up after ourselves */
  free(argv);

  return 2;
}

static const struct luaL_Reg getopt_funcs[] = {
  {"parse", lua_getopt},
	{NULL,	NULL}
};

int luaopen_getopt(lua_State* L)
{
  luaL_newlib(L, getopt_funcs);
  return 1;
}

