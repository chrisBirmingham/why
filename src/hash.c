#include <lua.h>
#include <lauxlib.h>

static const uint32_t C1 = 0xcc9e2d51;
static const uint32_t C2 = 0x1b873593;
static const uint32_t R1 = 15;
static const uint32_t R2 = 13;
static const uint32_t M = 5;
static const uint32_t N = 0xe6546b64;

static uint32_t murmur(const char* key, uint32_t len, uint32_t seed)
{
  uint32_t hash = seed;

  const int nblocks = len / 4;
  const uint32_t* blocks = (const uint32_t*) key;
  
  for (unsigned int i = 0; i < nblocks; i++) {
    uint32_t k = blocks[i];
    k *= C1;
    k = (k << R1) | (k >> (32 - R1));
    k *= C2;

    hash ^= k;
    hash = ((hash << R2) | (hash >> (32 - R2))) * M + N;
  }

  const uint8_t* tail = (const uint8_t*) (key + nblocks * 4);
  uint32_t k1 = 0;

  switch (len & 3) {
    case 3:
      k1 ^= tail[2] << 16;
    case 2:
      k1 ^= tail[1] << 8;
    case 1:
      k1 ^= tail[0];

      k1 *= C1;
      k1 = (k1 << R1) | (k1 >> (32 - R1));
      k1 *= C2;
      hash ^= k1;
  }

  hash ^= len;
  hash ^= (hash >> 16);
  hash *= 0x85ebca6b;
  hash ^= (hash >> 13);
  hash *= 0xc2b2ae35;
  hash ^= (hash >> 16);

  return hash;
}

static int lua_murmurhash(lua_State* L)
{
  size_t len;
  const char* s = luaL_checklstring(L, 1, &len);
  uint32_t hash = murmur(s, len, 0);
  lua_pushinteger(L, hash);
  return 1;
}

static const struct luaL_Reg hash_funcs[] = {
  {"murmur", lua_murmurhash},
  {NULL, NULL}
};

int luaopen_hash(lua_State* L)
{
  luaL_newlib(L, hash_funcs);
  return 1;
}

