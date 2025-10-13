#!/usr/bin/env lua

local arg = arg
local fs = require('fs')
local ipairs = ipairs
local mimetype = require('mimetype')
local pcall = pcall
local pairs = pairs
local scgi = require('scgi')
local server = require('server')
local string = string
local table = table
local tonumber = tonumber
local io = io

local function slurp(path)
  local file = io.open(path, 'rb')
  return file:read('*all')
end

local function endswith(str, needle)
  local suffix = str:sub(-(#needle))
  return suffix == needle
end

local function merge(t1, t2, iter)
  local iter = iter or pairs
  for k, v in iter(t2) do
    t1[k] = v
  end
end

local function split(str, pattern)
  local items = {}

  for s in str:gmatch(pattern) do
    items[s] = 1
  end

  return items
end

local function process_request(client, files)
  local request = client:recv()
  local status, headers = pcall(scgi.parse, request)

  if not status then
    error({code = 400, msg = headers})
  end

  local index = endswith(headers.REQUEST_URI, '/') and 'index.html' or ''
  local path = table.concat({headers.DOCUMENT_ROOT, headers.REQUEST_URI, index})

  if not files[path] then
    error({code = 404, msg = 'Unknown file'})
  end

  local file = files[path]
  local content = file.content
  local res_headers = {
    ['Content-Type'] = file.mime,
    ['Content-Length'] = file.length
  }

  if headers.HTTP_ACCEPT_ENCODING then
    local header = split(headers.HTTP_ACCEPT_ENCODING, '[^,%s]+')

    for _, encoding in ipairs({'br', 'gzip'}) do
      if header[encoding] and file[encoding] ~= nil then
        res_headers['Content-Encoding'] = encoding
        res_headers['Content-Length'] = file[encoding]['length']
        content = file[encoding]['content']
        break
      end
    end
  end

  return {
    content = content,
    headers = res_headers
  }
end

local function on_connect(client, files)
  local status, resp = pcall(process_request, client, files)
  client:send(scgi.build_header(resp.code or 200, resp.headers))
  client:send(resp.content or resp.msg)
  client:close()
end

local function get_compressed_file(path)
  if not fs.exist(path) then
    return nil
  end

  local content = slurp(path)
  return {
    content = content,
    length = #content
  }
end

local function add_file(path)
  local content = slurp(path)

  return {
    mime = mimetype.detect(fs.extname(path)),
    length = #content,
    content = content,
    gzip = get_compressed_file(path .. '.gz'),
    br = get_compressed_file(path .. '.br')
  }
end

local function get_files(dir)
  local files = {}

  if not endswith(dir, '/') then
    dir = dir .. '/'
  end

  for _, path in ipairs(fs.scandir(dir)) do
    if not endswith(path, '.gz') and not endswith(path, '.br') then
      if fs.is_dir(path) then
        merge(files, get_files(path))
      else
        files[path] = add_file(path)
      end
    end
  end

  return files
end

local function main()
  local document_root = arg[1]
  local files = get_files(document_root)

  for client in server.bind(8000) do
    on_connect(client, files)
  end
end

main()

