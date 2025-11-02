local error = error
local ipairs = ipairs
local loadfile = loadfile
local type = type

local config = {}

local function validate_config(conf)
  for _, v in ipairs({'port', 'document_root'}) do
    if not conf[v] then
      error(('Missing %s value'):format(v))
    end
  end

  local port = conf.port
  local t = type(port)

  if t ~= 'number' then
    error(('Bad port provided (%s). Should be a number, got %s'):format(port, t))
  end

  if port < 0 then
    error(('Bad port provided (%s)'):format(arg))
  end

  local document_root = conf.document_root

  if document_root:sub(-1) ~= '/' then
    conf.document_root = document_root .. '/'
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

