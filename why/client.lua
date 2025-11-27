local filestore = require('why.filestore')
local logging = require('why.logging')
local scgi = require('why.scgi')
local tablex = require('why.tablex')

local ipairs = ipairs
local STATUS = scgi.STATUS
local xpcall = xpcall

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

local function log_request(req, res)
  local msg = ('%s "%s %s %s" %s %s'):format(
    req.REMOTE_ADDR or DEFAULT_FIELD,
    req.REQUEST_METHOD or DEFAULT_FIELD,
    req.REQUEST_URI or DEFAULT_FIELD,
    req.SERVER_PROTOCOL or DEFAULT_FIELD,
    res.status or STATUS.BAD_REQUEST,
    res.headers['Content-Length'] or 0
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

local function log_error(err)
  local status = err.status or STATUS.INTERNAL_SERVER_ERROR
  local res = error_response(status, err.headers or {})

  if tablex.contains(status, {STATUS.INTERNAL_SERVER_ERROR, STATUS.BAD_REQUEST}) then

    logging.error(err.msg or err)
  end

  if err.req then
    log_request(err.req, res)
  end

  return scgi.build_response(res)
end

local function process_request(req)
  local method = req.REQUEST_METHOD

  if not ALLOWED_METHODS[method] then
    scgi.method_not_allowed(ALLOW_HEADER, req)
  end

  if method == 'OPTIONS' then
    return scgi.response(STATUS.NO_CONTENT, {Allow = ALLOW_HEADER})
  end

  local path = req.DOCUMENT_ROOT .. req.REQUEST_URI

  local file = filestore.get(path)

  if not file then
    scgi.not_found(req)
  end

  local content = file.content
  local etag = file.etag
  local res_headers = {
    ['Content-Type'] = file.mime,
    ['Content-Length'] = file.length,
    ETag = etag
  }

  local none_match = req.HTTP_IF_NONE_MATCH or ''

  if none_match == etag then
    return scgi.response(STATUS.NOT_MODIFIED, {ETag = etag})
  end

  local accept_encoding = req.HTTP_ACCEPT_ENCODING or {}

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

function client.handle(req_body)
  local res
  local ok, req = xpcall(scgi.parse_request, log_error, req_body)

  if not ok then
    return req
  end

  ok, res = xpcall(scgi.validate_request, log_error, req)

  if not ok then
    return res
  end

  ok, res = xpcall(process_request, log_error, req)

  if not ok then
    return res
  end

  log_request(req, res)
  return scgi.build_response(res)
end

return client

