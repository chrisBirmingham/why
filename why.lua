#!/usr/bin/env lua5.4

local client_processor = require('why.client')
local config = require('why.config')
local event = require('why.event')
local filestore = require('why.filestore')
local getopt = require('why.getopt')
local logging = require('why.logging')
local notify = require('why.notify')
local os = os
local pcall = pcall
local print = print
local socket = require('why.socket')

local USAGE = [[Usage: why [OPTIONS] [CONFIG_FILE]
A SCGI static file server

  -f Filename of the config file (Default /etc/why/conf.lua)
  -t Test the config file and exit
  -v Print version and exit
  -h Show this message and exit

Examples:
  why -f /etc/why/conf.lua - Use this file as Why's config
  why -t -f /etc/why/conf.lua - Test the provided config file]]

local VERSION = '1.0.0'
local config_file = '/etc/why/conf.lua'

local function create_server(port)
  local conn = socket.tcp(port)
  conn:listen(10)
  return conn
end

local function load_files(document_root)
  logging.info('Document root is ' .. document_root)
  filestore.document_root = document_root
  filestore:clear()
  filestore:scan()
end

local function run_server(conf)
  logging.info('Loading files')
  load_files(conf.document_root)
  logging.info('Files have been loaded')

  local conn = create_server(conf.port)
  local loop = event:new_eventloop()

  conn:onconnect(loop, client_processor.handle)

  local function kill()
    notify.send(notify.STOPPING, 'Service stopping')
    logging.info('Quitting')
    loop:stop()
    conn:close()
    os.exit()
  end

  -- Sigint is via terminal
  loop:signal(event.SIGINT, kill)
  -- Sigterm is via service
  loop:signal(event.SIGTERM, kill)

  loop:signal(event.SIGHUP, function()
    logging.info('Reloading service')
    notify.send(notify.RELOADING)
    loop:stop()
    conn:close()
  end)

  notify.send(notify.READY, 'Service started/reloaded successfully')
  logging.info('Listening on port ' .. conf.port)
  loop:run()
end

local function parse_args()
  local validate_config = false

  getopt.parse('vhf:t', function(opt, arg)
    if opt == 'h' then
      print(USAGE)
      os.exit()
    elseif opt == 'v' then
      print(VERSION)
      os.exit()
    elseif opt == 'f' then
      config_file = arg
    elseif opt == 't' then
      validate_config = true
    end
  end)

  return validate_config
end

local function main()
  local validate_config = parse_args()
  notify.setup()

  -- Continually loop. If we get a sighup, we'll load the configs again and
  -- restart the server
  while true do
    local conf = config.load(config_file)

    if validate_config then
      logging.info(('Config file %s is valid'):format(config_file))
      return
    end

    run_server(conf)
  end
end

local ok, err = pcall(main)

if not ok then
  io.stderr:write(err .. "\n")
  os.exit(1)
end

