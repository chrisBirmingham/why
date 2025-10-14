#include <lua.h>
#include <lauxlib.h>

static uint32_t murmur(const char* key, uint32_t len, uint32_t seed)
{
  const uint32_t c1 = 0xcc9e2d51;
  const uint32_t c2 = 0x1b873593;
  const uint32_t r1 = 15;
  const uint32_t r2 = 13;
  const uint32_t m = 5;
  const uint32_t n = 0xe6546b64;

  uint32_t hash = seed;

  const int nblocks = len / 4;
  const uint32_t *blocks = (const uint32_t *) key;
  
  for (unsigned int i = 0; i < nblocks; i++) {
    uint32_t k = blocks[i];
    k *= c1;
    k = (k << r1) | (k >> (32 - r1));
    k *= c2;

    hash ^= k;
    hash = ((hash << r2) | (hash >> (32 - r2))) * m + n;
  }

  const uint8_t *tail = (const uint8_t *) (key + nblocks * 4);
  uint32_t k1 = 0;

  switch (len & 3) {
    case 3:
      k1 ^= tail[2] << 16;
    case 2:
      k1 ^= tail[1] << 8;
    case 1:
      k1 ^= tail[0];

      k1 *= c1;
      k1 = (k1 << r1) | (k1 >> (32 - r1));
      k1 *= c2;
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
	{NULL,	NULL}
};

int luaopen_hash(lua_State* L)
{
  luaL_newlib(L, hash_funcs);
  return 1;
}

