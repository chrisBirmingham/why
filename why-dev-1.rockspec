package = 'why'
version = 'dev-1'
source = {
  url = "https://github.com/chrisBirmingham/why.git"
}
description = {
  summary = 'A SCGI static file server.',
  detailed = [[An event driven Lua SCGI web server that serves all requests from memory. Influenced by StaticHttpFileServer.]],
  homepage = "*** please enter a project homepage ***",
  license = 'Unlicense'
}
dependencies = {
  'lua = 5.4'
}
build = {
  type = 'builtin',
  modules = {
    ['why.config'] = 'why/config.lua',
    ['why.common'] = 'why/common.lua',
    ['why.client'] = 'why/client.lua',
    ['why.event'] = {
      sources = 'why/event.c',
      libraries = {'ev'}
    },
    ['why.filestore'] = 'why/filestore.lua',
    ['why.fs'] = {
      sources = 'why/fs.c'
    },
    ['why.getopt'] = {
      sources = 'why/getopt.c'
    },
    ['why.hash'] = {
      sources = 'why/hash.c'
    },
    ['why.logging'] = 'why/logging.lua',
    ['why.mimetype'] = {
      sources = 'why/mimetype.c',
      libraries = {'magic'}
    },
    ['why.notify'] = 'why/notify.lua',
    ['why.scgi'] = 'why/scgi.lua',
    ['why.socket'] = {
      sources = 'why/socket.c',
      libraries = {'ev'}
    }
  },
  install = {
    bin = {
      why = 'why.lua'
    }
  }
}

