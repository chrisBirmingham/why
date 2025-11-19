local filestore = require('why.filestore')
local logging = require('why.logging')
local scgi = require('why.scgi')
local tablex = require('why.tablex')

local ipairs = ipairs
local pcall = pcall
local STATUS = scgi.STATUS

local client = {}

local ALLOW_HEADER = 'HEAD, GET, OPTIONS'
local DEFAULT_FIELD = '-'

local function log_request(request, status, size)
  local msg = ('%s "%s %s %s" %s %s'):format(
    request.REMOTE_ADDR or DEFAULT_FIELD,
    request.REQUEST_METHOD or DEFAULT_FIELD,
    request.REQUEST_URI or DEFAULT_FIELD,
    request.SERVER_PROTOCOL or DEFAULT_FIELD,
    status,
    size
  )
  logging.info(msg)
end

local function error_response(res)
  local content = scgi.error_page(res.status)
  res.headers['Content-Length'] = #content
  res.headers['Content-Type'] = 'text/html'
  return content
end

local function process_request(request)
  local method = request.REQUEST_METHOD

  if not tablex.contains(method, {'HEAD', 'GET', 'OPTIONS'}) then
    return scgi.response(STATUS.METHOD_NOT_ALLOWED, {Allow = ALLOW_HEADER})
  end

  if method == 'OPTIONS' then
    return scgi.response(STATUS.NO_CONTENT, {Allow = ALLOW_HEADER})
  end

  local path = request.DOCUMENT_ROOT .. request.REQUEST_URI

  local file = filestore.get(path)

  if not file then
    return scgi.response(STATUS.NOT_FOUND)
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

  for _, encoding in ipairs({'br', 'gzip'}) do
    if accept_encoding[encoding] and file[encoding] then
      res_headers['Content-Encoding'] = encoding
      res_headers['Content-Length'] = file[encoding].length
      content = file[encoding].content
      break
    end
  end

  local response = scgi.response(STATUS.OK, res_headers)

  if method == 'HEAD' then
    return response
  end

  return response, content
end

function client.handle(request)
  local ok, err
  local res = scgi.response(STATUS.BAD_REQUEST)
  local content = error_response(res)

  ok, request = pcall(scgi.parse_request, request)

  -- If the request is invalid, we can't be sure we have enough data to
  -- log in the access log so send to error log
  if not ok then
    logging.error(request)
    return scgi.response_headers(res), content
  end

  ok, err = pcall(scgi.validate_request, request)

  if not ok then
    logging.error(err)
    log_request(request, res.status, #content)
    return scgi.response_headers(res), content
  end

  res, content = process_request(request)

  if res.status >= 400 then
    content = error_response(res)
  end

  log_request(request, res.status, #(content or ''))
  return scgi.response_headers(res), content
end

return client

