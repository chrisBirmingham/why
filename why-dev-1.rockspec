package = 'why'
version = 'dev-1'
source = {
  url = "git+ssh://git@git.intermaterium.com/intermaterium/why.git"
}
description = {
  summary = 'A Lua SCGI web server.',
  detailed = [[
A Lua SCGI web server that reads all files within the document root and stores
them into memory. When serving requests, Why doesn't make any filesystem
accesses and serves everything from memory.]],
  homepage = "*** please enter a project homepage ***",
  license = 'Unlicense'
}
dependencies = {
  'lua = 5.4'
}
build = {
  type = 'builtin',
  modules = {
    ['why.common'] = 'src/why/common.lua',
    ['why.filestore'] = 'src/why/filestore.lua',
    ['why.fs'] = {
      sources = 'src/why/fs.c'
    },
    ['why.getopt'] = {
      sources = 'src/why/getopt.c'
    },
    ['why.hash'] = {
      sources = 'src/why/hash.c'
    },
    ['why.mimetype'] = {
      sources = 'src/why/mimetype.c',
      libraries = {'magic'}
    },
    ['why.scgi'] = 'src/why/scgi.lua',
    ['why.server'] = {
      sources = 'src/why/server.c',
      libraries = {'ev'}
    }
  },
  install = {
    bin = {
      why = 'src/why.lua'
    }
  }
}

