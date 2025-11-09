local error = error
local filestore = require('why.filestore')
local ipairs = ipairs
local logging = require('why.logging')
local pcall = pcall
local scgi = require('why.scgi')
local STATUS = scgi.STATUS
local tablex = require('why.tablex')

local client = {}

local ALLOW_HEADER = 'HEAD, GET, OPTIONS'

local function process_request(request)
  local ok, headers = pcall(scgi.parse_request, request)

  if not ok then
    logging.error('Invalid client request: ' .. headers)
    error(scgi.response(STATUS.BAD_REQUEST))
  end

  local method = headers.REQUEST_METHOD

  if not tablex.contains(method, {'HEAD', 'GET', 'OPTIONS'}) then
    logging.error('Invalid method requested ' .. method)
    error(scgi.response(STATUS.METHOD_NOT_ALLOWED, {Allow = ALLOW_HEADER}))
  end

  if method == 'OPTIONS' then
    return scgi.response(STATUS.NO_CONTENT, {Allow = ALLOW_HEADER})
  end

  local path = headers.DOCUMENT_ROOT .. headers.REQUEST_URI

  local file = filestore:get(path)

  if not file then
    logging.error('File not found ' .. path)
    error(scgi.response(STATUS.NOT_FOUND))
  end

  local content = file.content
  local etag = file.etag
  local res_headers = {
    ['Content-Type'] = file.mime,
    ['Content-Length'] = file.length,
    ETag = etag
  }

  local none_match = headers.HTTP_IF_NONE_MATCH or ''

  if none_match == etag then
    return scgi.response(STATUS.NOT_MODIFIED, {ETag = etag})
  end

  local accept_encoding = headers.HTTP_ACCEPT_ENCODING or {}

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
  local ok, res, content = pcall(process_request, request)

  if not ok then
    content = scgi.error_page(res.status)
    res.headers['Content-Length'] = #content
    res.headers['Content-Type'] = 'text/html'
  end

  return scgi.response_headers(res), content
end

return client

