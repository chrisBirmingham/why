#!/usr/bin/env lua5.4

require('why.common')
local filestore = require('why.filestore')
local getopt = require('why.getopt')
local ipairs = ipairs
local loadfile = loadfile
local os = os
local pcall = pcall
local print = print
local scgi = require('why.scgi')
local server = require('why.server')
local STATUS = scgi.STATUS
local table = table
local tonumber = tonumber
local type = type

local USAGE = [[Usage: why [OPTIONS] [DOCUMENT_ROOT]
A SCGI static file server

  -p The port to use (Default 8000)
  -f Filename of the config file
  -v Print version and exit
  -h Show this message and exit

Examples:
  why -p 8000 /var/www/html - Listen on port 8000 and use /var/www/html as the document root
  why -f /etc/why.lua - Use this file as Why's config]]

local VERSION = '1.0.0'
local DEFAULT_PORT = 8000

local function throw(err)
  io.stderr:write(("%s: %s\n"):format(arg[0], err))
  os.exit(1)
end

local function process_request(request, files)
  local ok, headers = pcall(scgi.parse_request, request)

  if not ok then
    return scgi.build_error_response(STATUS.BAD_REQUEST)
  end

  local method = headers.REQUEST_METHOD

  if not table.contains(method, {'HEAD', 'GET', 'OPTIONS'}) then
    return scgi.build_error_response(STATUS.METHOD_NOT_ALLOWED)
  end

  if method == 'OPTIONS' then
    return scgi.build_response(STATUS.NO_CONTENT, {Allow = 'OPTIONS, HEAD, GET'})
  end

  local path = headers.DOCUMENT_ROOT .. headers.REQUEST_URI

  if not files[path] then
    return scgi.build_error_response(STATUS.NOT_FOUND)
  end

  local file = files[path]
  local content = file.content
  local etag = file.etag
  local res_headers = {
    ['Content-Type'] = file.mime,
    ['Content-Length'] = file.length,
    ETag = etag
  }

  local none_match = headers.HTTP_IF_NONE_MATCH or ''

  if none_match == etag then
    return scgi.build_response(STATUS.NOT_MODIFIED, {ETag = etag})
  end

  local accept_encoding = headers.HTTP_ACCEPT_ENCODING or {}

  for _, encoding in ipairs({'br', 'gzip'}) do
    if accept_encoding[encoding] and file[encoding] then
      res_headers['Content-Encoding'] = encoding
      res_headers['Content-Length'] = file[encoding].length
      content = file[encoding].content
      break
    end
  end

  local response = scgi.build_response(STATUS.OK, res_headers)

  if method == 'HEAD' then
    return response
  end

  return response, content
end

local function serve(document_root, port)
  print(('Loading files from %s'):format(document_root))
  local files = filestore.get_files(document_root)
  print('Files have been loaded')

  print('Listening on port ' .. port)
  server.listen(port,
    function(client)
      local ok, headers, content = pcall(process_request, client:recv(), files)

      if not ok then
        headers, content = scgi.build_error_response(STATUS.INTERNAL_SERVER_ERROR)
      end

      client:send(headers)

      if content then
        client:send(content)
      end
    end)
end

local function load_config(path)
  local func, err = loadfile(path, 't', {})

  if err then
    throw(err)
  end

  local conf = func()
  local t = type(conf)

  if t ~= 'table' then
    throw(('Invalid config file %s: Format should be a table, got %s'):format(path, t))
  end

  return conf
end

local function parse_args()
  local doc_root = nil
  local port = DEFAULT_PORT
  local conf = nil

  local args = getopt.parse('vhp:f:', function(opt, arg)
    if opt == 'h' then
      print(USAGE)
      os.exit()
    elseif opt == 'v' then
      print(VERSION)
      os.exit()
    elseif opt == 'p' then
      -- If we've been provided a config file, ignore this option
      if conf then
        return
      end

      port = tonumber(arg)
      if not port or port < 0 then
        throw(('Invalid port provided (%s)'):format(arg))
      end
    elseif opt == 'f' then
      conf = load_config(arg)

      for _, v in ipairs({'port', 'doc_root'}) do
        if not conf[v] then
          throw(('Invalid config file %s: Missing %s value'):format(arg, v))
        end
      end

      port = conf.port
      doc_root = conf.doc_root
    end
  end)

  doc_root = doc_root or args[1]

  if not doc_root then
    throw([[Missing document root argument
Try 'why -h' for more information]])
  end

  return doc_root, port
end

local function main()
  local doc_root, port = parse_args()
  serve(doc_root, port)
end

local ok, err = pcall(main)

if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end

