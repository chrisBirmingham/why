require('why.common')
local fs = require('why.fs')
local hash = require('why.hash')
local io = io
local ipairs = ipairs
local mimetype = require('why.mimetype')
local pairs = pairs
local table = table

local magic = mimetype.open()

local COMMON_MIMETYPES = {
  ['.html'] = 'text/html',
  ['.htm'] = 'text/html',
  ['.css'] = 'text/css',
  ['.txt'] = 'text/plain',
  ['.jpg'] = 'image/jpeg',
  ['.jpeg'] = 'image/jpeg',
  ['.png'] = 'image/png',
  ['.gif'] = 'image/gif',
  ['.js'] = 'application/javascript'
}

local function slurp(path)
  local file = io.open(path, 'rb')
  return file:read('*all')
end

local function get_compressed_files(path, file)
  for algo, ext in pairs({gzip = '.gz', br = '.br'}) do
    local compressed = path .. ext
    if fs.exist(compressed) then
      local content = slurp(compressed)
      file[algo] = {
        content = content,
        length = #content
      }
    end
  end
end

local function process_file(path, ext)
  local content = slurp(path)

  local file = {
    mime = COMMON_MIMETYPES[ext] or magic:detect(path),
    length = #content,
    content = content,
    etag = ("%x"):format(hash.murmur(content))
  }

  get_compressed_files(path, file)
  return file
end

local filestore = {
  files = {},
  document_root = ''
}

function filestore:clear()
  self.files = {}
end

function filestore:get(path)
  return self.files[path] or nil
end

function filestore:scan(dir)
  dir = dir or self.document_root

  for _, path in ipairs(fs.scandir(dir)) do
    if fs.is_dir(path) then
      self:scan(path)
    else
      local basename, ext = fs.fnparts(path)

      if not table.contains(ext, {'.gz', '.br'}) then
        local file = process_file(path, ext)
        self.files[path] = file

        -- If we have an index file, alias the directory to it
        if basename == 'index.html' then
          self.files[dir] = file
        end
      end
    end
  end
end

return filestore

