local io = io
local os = os

local logging = {}

function logging.error(msg)
  local date = os.date('%Y-%m-%d %H:%M:%S')
  io.stderr:write(('[%s] %s\n'):format(date, msg))
end

return logging

