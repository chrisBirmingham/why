#!/usr/bin/env lua5.4

local client_processor = require('why.client')
local filestore = require('why.filestore')
local getopt = require('why.getopt')
local ipairs = ipairs
local loadfile = loadfile
local os = os
local pcall = pcall
local print = print
local server = require('why.server')
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

  if not (doc_root:sub(-1) == '/') then
    doc_root = doc_root .. '/'
  end

  return doc_root, port
end

local function main()
  local document_root, port = parse_args()

  print(('Loading files from %s'):format(document_root))
  filestore:scan(document_root)
  print('Files have been loaded')

  print(('Listening on port %d'):format(port))
  server.listen(port, client_processor.handle)
end

local ok, err = pcall(main)

if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end

