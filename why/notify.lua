local socket = require('why.socket')

local os = os

local NOTIFY_SOCKET = 'NOTIFY_SOCKET'

local notify = {
  READY = 'READY=1',
  RELOADING = 'RELOADING=1',
  STOPPING = 'STOPPING=1'
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

  local message = msg_type

  if status then
    message = ("%s\nSTATUS=%s"):format(msg_type, status)
  end

  sock:send(message .. '\n')
end

return notify

