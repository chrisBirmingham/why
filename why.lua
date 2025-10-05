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

  local request_uri = headers.REQUEST_URI

  if endswith(request_uri, '/') then
    request_uri = request_uri .. 'index.html'
  end

  local index = endswith(headers.REQUEST_URI, '/') and 'index.html' or ''
  local path = table.concat({headers.DOCUMENT_ROOT, headers.REQUEST_URI, index})

  if not files[path] then
    error({code = 404, msg = 'Unknown file'})
  end

  local content = slurp(path)
  return { ['Content-Type'] = files[path] }, content
end

local function get_files(dir, files)
  files = files or {}

  for item in fs.scandir(dir) do
    if item ~= '.' and item ~= '..' then
      local path = table.concat({dir, '/', item})

      if fs.is_dir(path) then
        get_files(path, files)
      else
        local realpath = fs.realpath(path)
        files[realpath] = mimetype.detect(fs.extname(realpath))
      end
    end
  end

  return files
end

local function main()
  local document_root = arg[1]
  local files = get_files(document_root)
  local socket = server.bind(8000)

  while true do
    local client = socket:accept()
    local status, resp, body = pcall(process_request, client, files)

    if not status then
      client:send(scgi.build_header(resp.code, {}))
      client:send(resp.msg)
    else
      client:send(scgi.build_header(200, resp))
      client:send(body)
    end

    client:close()
  end
end

main()

