#!/usr/bin/env lua

local arg = arg
local fs = require('fs')
local pcall = pcall
local mimetype = require('mimetype')
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

  return files[path]
end

local function get_files(dir, files)
  files = files or {}

  for item in fs.scandir(dir) do
    local path = table.concat({dir, '/', item})

    if fs.is_dir(path) then
      get_files(path, files)
    else
      local realpath = fs.realpath(path)
      local content = slurp(path)

      files[realpath] = {
        headers = {
          ['Content-Type'] = mimetype.detect(fs.extname(realpath)),
          ['Content-Length'] = #content
        },
        content = content
      }
    end
  end

  return files
end

local function on_connect(client, files)
  local status, resp = pcall(process_request, client, files)
  client:send(scgi.build_header(resp.code or 200, resp.headers))
  client:send(resp.content or resp.msg)
  client:close()
end

local function main()
  local document_root = arg[1]
  local files = get_files(document_root)

  for client in server.bind(8000) do
    on_connect(client, files)
  end
end

main()

