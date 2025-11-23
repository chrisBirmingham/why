local socket = require('why.socket')

local os = os
local table = table

local NOTIFY_SOCKET = 'NOTIFY_SOCKET'

local notify = {
  READY = 'READY=1\n',
  RELOADING = 'RELOADING=1\n',
  STOPPING = 'STOPPING=1\n'
}

local sock = nil

function notify.setup()
  local path = os.getenv(NOTIFY_SOCKET)

  if not path then
    return
  end

  sock = socket.open(path, socket.SOCK_DGRAM, socket.CONNECT)
end

function notify.send(msg_type, status)
  if not sock then
    return
  end

  local message = {msg_type}

  if status then
    table.insert(message, ("STATUS=%s\n"):format(status))
  end

  sock:send(message)
end

return notify

