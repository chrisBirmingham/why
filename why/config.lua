local error = error
local loadfile = loadfile
local type = type

local config = {}

local function check_type(field, value, expected)
  local t = type(value)

  if t ~= expected then
    error(('Bad %s provided (%s). Should be a %s, got %s'):format(field, value, expected, t))
  end
end

local function validate_config(conf)
  if not conf.document_root then
    error('Missing required document_root value')
  end

  local document_root = conf.document_root
  check_type('document_root', document_root, 'string')

  if document_root == '' then
    error('document_root cannot be empty')
  end

  if document_root:sub(-1) ~= '/' then
    conf.document_root = document_root .. '/'
  end

  if not conf.port and not conf.socket then
    error('Missing one of required fields, port or socket')
  end

  if conf.port and conf.socket then
    error('port and socket cannot both be defined')
  end

  if conf.port then
    local port = conf.port
    check_type('port', port, 'number')

    if port < 0 then
      error(('Bad port provided (%s)'):format(arg))
    end
  end

  if conf.socket then
    local socket = conf.socket
    check_type('socket', socket, 'string')

    if socket == '' then
      error('socket cannot be empty')
    end
  end
end

local function read_config(path)
  local func, err = loadfile(path, 't', {})

  if err then
    error(err)
  end

  local conf = func()
  local t = type(conf)

  if t ~= 'table' then
    error(('Invalid config file %s: Format should be a table, got %s'):format(path, t))
  end

  return conf
end

function config.load(path)
  local conf = read_config(path)

  local ok, err = pcall(validate_config, conf)

  if not ok then
    error(('Invalid config file %s: %s'):format(path, err))
  end

  return conf
end

return config

