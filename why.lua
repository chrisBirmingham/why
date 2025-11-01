#!/usr/bin/env lua5.4

local client_processor = require('why.client')
local eventloop = require('why.eventloop')
local filestore = require('why.filestore')
local getopt = require('why.getopt')
local ipairs = ipairs
local loadfile = loadfile
local logging = require('why.logging')
local notify = require('why.notify')
local os = os
local pcall = pcall
local print = print
local socket = require('why.socket')
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

  if doc_root:sub(-1) ~= '/' then
    doc_root = doc_root .. '/'
  end

  return doc_root, port
end

local function create_server(loop, port)
  local conn = socket.tcp(port)
  conn:listen(10)
  conn:onconnect(loop, client_processor.handle)
  return conn
end

local function load_files()
  logging.info('Loading files')
  filestore:scan()
  logging.info('Files have been loaded')
end

local function run_server(port)
  local loop = eventloop:new()

  loop:signal(eventloop.SIGINT, function()
    logging.info('Quitting')
    loop:stop()
  end)

  local conn = create_server(loop, port)
  logging.info('Listening on port ' .. port)

  -- Tell service manager we're ready
  notify.ready()
  loop:run()
  conn:close()
end

local function main()
  local document_root, port = parse_args()
  notify.setup()

  logging.info('Document root is ' .. document_root)
  filestore.document_root = document_root
  load_files()

  run_server(port)
  notify.stopping()
end

local ok, err = pcall(main)

if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end

