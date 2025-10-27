require('common')
local fs = require('fs')
local hash = require('hash')
local io = io
local ipairs = ipairs
local mimetype = require('mimetype')
local pairs = pairs
local pcall = pcall
local table = table

local filestore = {}

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

local function add_file(path, ext)
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

function filestore.get_files(dir)
  local files = {}

  if not dir:endswith('/') then
    dir = dir .. '/'
  end

  for _, path in ipairs(fs.scandir(dir)) do
    if fs.is_dir(path) then
      table.merge(files, filestore.get_files(path))
    else
      local basename, ext = fs.fnparts(path)

      if not table.contains(ext, {'.gz', '.br'}) then
        local file = add_file(path, ext)
        files[path] = file

        -- If we have an index file, alias the directory to it
        if basename == 'index.html' then
          files[dir] = file
        end
      end
    end
  end

  return files
end

return filestore

