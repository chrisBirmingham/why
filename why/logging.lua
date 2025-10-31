local io = io
local os = os

local logging = {}

local function log(msg, fp)
  local date = os.date('%Y-%m-%d %H:%M:%S')
  fp:write(('[%s] %s\n'):format(date, msg))
end

function logging.info(msg)
  log(msg, io.stdout)
end

function logging.error(msg)
  log(msg, io.stderr)
end

return logging

