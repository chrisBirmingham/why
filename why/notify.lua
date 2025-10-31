local os = os
local socket = require('why.socket')

local NOTIFY_SOCKET = 'NOTIFY_SOCKET'
local READY_MSG = 'READY=1\n'
local STOPPING_MSG = 'STOPPING=1\n'

local notify = {}
local sock = nil

function notify.setup()
  local path = os.getenv(NOTIFY_SOCKET)

  if not path then
    return
  end

  sock = socket.unix(path, socket.SOCK_DGRAM)
end

local function send(msg)
  if not sock then
    return
  end

  sock:send(msg)
end

function notify.ready()
  send(READY_MSG)
end

function notify.stopping()
  send(STOPPING_MSG)
end

return notify

