require('why.common')
local filestore = require('why.filestore')
local ipairs = ipairs
local logging = require('why.logging')
local pcall = pcall
local scgi = require('why.scgi')
local STATUS = scgi.STATUS
local table = table

local client = {}

local ALLOW_HEADER = 'HEAD, GET, OPTIONS'

local function process_request(request)
  local ok, headers = pcall(scgi.parse_request, request)

  if not ok then
    logging.error('Invalid client request: ' .. headers)
    return scgi.build_error_response(STATUS.BAD_REQUEST)
  end

  local method = headers.REQUEST_METHOD

  if not table.contains(method, {'HEAD', 'GET', 'OPTIONS'}) then
    return scgi.build_error_response(STATUS.METHOD_NOT_ALLOWED, {Allow = ALLOW_HEADER})
  end

  if method == 'OPTIONS' then
    return scgi.build_response(STATUS.NO_CONTENT, {Allow = ALLOW_HEADER})
  end

  local path = headers.DOCUMENT_ROOT .. headers.REQUEST_URI

  local file = filestore:get(path)

  if not file then
    logging.error('File not found ' .. path)
    return scgi.build_error_response(STATUS.NOT_FOUND)
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
    return scgi.build_response(STATUS.NOT_MODIFIED, {ETag = etag})
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

  local response = scgi.build_response(STATUS.OK, res_headers)

  if method == 'HEAD' then
    return response
  end

  return response, content
end

function client.handle(conn)
  local ok, headers, content = pcall(process_request, conn:recv())

  if not ok then
    headers, content = scgi.build_error_response(STATUS.INTERNAL_SERVER_ERROR)
  end

  conn:send(headers)

  if content then
    conn:send(content)
  end

  conn:close()
end

return client

