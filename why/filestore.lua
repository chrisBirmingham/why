local fs = require('why.fs')
local hash = require('why.hash')
local mimetype = require('why.mimetype')
local tablex = require('why.tablex')

local io = io
local ipairs = ipairs
local os = os
local pairs = pairs

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
    mtime = fs.mtime(path),
    mime = COMMON_MIMETYPES[ext] or magic:detect(path),
    length = #content,
    content = content,
    etag = ("%x"):format(hash.murmur(content))
  }

  get_compressed_files(path, file)
  return file
end

local filestore = {}
local files = {}

function filestore.get(path)
  return files[path] or nil
end

function filestore.scan(document_root)
  local unix_epoch = os.time()
  local processed_files = {}

  local function loop(dir)
    for _, path in ipairs(fs.scandir(dir)) do
      if fs.is_dir(path) then
        loop(path)
      else
        local basename, ext = fs.fnparts(path)

        if not tablex.contains(ext, {'.gz', '.br'}) then
          local is_index = basename == 'index.html'
          processed_files[path] = 1

          if is_index then
            processed_files[dir] = 1
          end

          -- Check to see if we haven't already processed this file or if the
          -- file's been modifed in the meantime
          if not files[path] or unix_epoch > files[path].mtime then
            local file = process_file(path, ext)
            files[path] = file

            -- If we have an index file, alias the directory to it
            if is_index then
              files[dir] = file
            end
          end
        end
      end
    end
  end

  loop(document_root)

  -- Remove any files that have since been removed
  for file, _ in pairs(files) do
    if not processed_files[file] then
      files[file] = nil
    end
  end
end

return filestore

