local filestore = require('why.filestore')
local logging = require('why.logging')
local scgi = require('why.scgi')

local ipairs = ipairs
local pcall = pcall
local STATUS = scgi.STATUS

local client = {}
local ERROR_RESPONSES = {}

local ALLOWED_METHODS = {
  HEAD = 1,
  GET = 1,
  OPTIONS = 1
}

local ENCODINGS = {'br', 'gzip'}
local ALLOW_HEADER = 'HEAD, GET, OPTIONS'
local DEFAULT_FIELD = '-'

local function log_request(request, status, size)
  local msg = ('%s "%s %s %s" %s %s'):format(
    request.REMOTE_ADDR or DEFAULT_FIELD,
    request.REQUEST_METHOD or DEFAULT_FIELD,
    request.REQUEST_URI or DEFAULT_FIELD,
    request.SERVER_PROTOCOL or DEFAULT_FIELD,
    status or STATUS.BAD_REQUEST,
    size or 0
  )
  logging.info(msg)
end

local function error_response(status, headers)
  if ERROR_RESPONSES[status] then
    return ERROR_RESPONSES[status]
  end

  local res = scgi.error_response(status, headers)
  ERROR_RESPONSES[status] = res
  return res
end

local function process_request(request)
  local method = request.REQUEST_METHOD

  if not ALLOWED_METHODS[method] then
    return error_response(STATUS.METHOD_NOT_ALLOWED, {Allow = ALLOW_HEADER})
  end

  if method == 'OPTIONS' then
    return scgi.response(STATUS.NO_CONTENT, {Allow = ALLOW_HEADER})
  end

  local path = request.DOCUMENT_ROOT .. request.REQUEST_URI

  local file = filestore.get(path)

  if not file then
    return error_response(STATUS.NOT_FOUND)
  end

  local content = file.content
  local etag = file.etag
  local res_headers = {
    ['Content-Type'] = file.mime,
    ['Content-Length'] = file.length,
    ETag = etag
  }

  local none_match = request.HTTP_IF_NONE_MATCH or ''

  if none_match == etag then
    return scgi.response(STATUS.NOT_MODIFIED, {ETag = etag})
  end

  local accept_encoding = request.HTTP_ACCEPT_ENCODING or {}

  for _, encoding in ipairs(ENCODINGS) do
    if accept_encoding[encoding] and file[encoding] then
      res_headers['Content-Encoding'] = encoding
      res_headers['Content-Length'] = file[encoding].length
      content = file[encoding].content
      break
    end
  end

  if method == 'HEAD' then
    return scgi.response(STATUS.OK, res_headers)
  end

  return scgi.response(STATUS.OK, res_headers, content)
end

function client.handle(request)
  local ok, err
  local res = error_response(STATUS.BAD_REQUEST)

  ok, request = pcall(scgi.parse_request, request)

  -- If the request is invalid, we can't be sure we have enough data to
  -- log in the access log so send to error log
  if not ok then
    logging.error(request)
    return res
  end

  ok, err = pcall(scgi.validate_request, request)

  if not ok then
    logging.error(err)
    log_request(request, res.status, res.headers['Content-Length'] or 0)
    return res
  end

  res = process_request(request)
  log_request(request, res.status, res.headers['Content-Length'] or 0)
  return scgi.build_response(res)
end

return client

