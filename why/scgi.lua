local error = error
local pairs = pairs
local table = table
local tonumber = tonumber

local scgi = {}

scgi.STATUS = {
  OK = 200,
  NO_CONTENT = 204,
  NOT_MODIFIED = 304,
  BAD_REQUEST = 400,
  NOT_FOUND = 404,
  METHOD_NOT_ALLOWED = 405,
  INTERNAL_SERVER_ERROR = 500
}

local STATUS_LINES = {
  [200] = '200 Ok',
  [204] = '204 No Content',
  [304] = '304 Not Modified',
  [400] = '400 Bad Request',
  [404] = '404 Not Found',
  [405] = '405 Method Not Allowed',
  [500] = '500 Internal Server Error'
}

local ERROR_MESSAGES = {
  [400] = 'Server received an invalid request',
  [404] = 'The requested file doesn\'t exist',
  [405] = 'The requested HTTP method is not allowed',
  [500] = 'Server encountered an error while processing the request'
}

local ERROR_PAGE = [[
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>$status</title>
  </head>
  <body>
    <h1>$status</h1>
    <p>$message</p>
  </body>
</html>
]]

local function split_header(header)
  local items = {}

  for s in header:gmatch('[^,%s]+') do
    items[s] = 1
  end

  return items
end

function scgi.bad_request(msg, req)
  error({
    status = scgi.STATUS.BAD_REQUEST,
    msg = msg,
    req = req
  })
end

function scgi.not_found(req)
  error({
    status = scgi.STATUS.NOT_FOUND,
    req = req
  })
end

function scgi.method_not_allowed(allow_header, req)
  error({
    status = scgi.STATUS.METHOD_NOT_ALLOWED,
    headers = {
      Allow = allow_header
    },
    req = req
  })
end

function scgi.validate_request(req)
  -- enforce base 10, we should never have CONTENT_LENGTH: 0xFF (lol)
  if not tonumber(req.CONTENT_LENGTH, 10) then
    scgi.bad_request('CONTENT_LENGTH header value is not a number', req)
  end

  if not req.SCGI then
    scgi.bad_request('Missing SCGI header', req)
  end

  if req.SCGI ~= '1' then
    scgi.bad_request('SCGI header value is not 1', req)
  end
end

function scgi.parse_request(request)
  local netsize, scgistart = request:match('^(%d+):()')

  if not netsize then
    scgi.bad_request('Missing starting netstring')
  end

  local head = request:sub(scgistart, scgistart + netsize)
  local headers = {}
  local first_header = true

  for k, v in head:gmatch('(%Z+)%z(%Z*)%z') do
    if headers[k] then
      scgi.bad_request('Duplicate SCGI header encountered')
    end

    if first_header then
      first_header = false

      if k ~= 'CONTENT_LENGTH' then
        scgi.bad_request('CONTENT_LENGTH was not the first header')
      end
    end

    headers[k] = v
  end

  if headers.HTTP_ACCEPT_ENCODING then
    headers.HTTP_ACCEPT_ENCODING = split_header(headers.HTTP_ACCEPT_ENCODING)
  end

  return headers
end

function scgi.build_response(res)
  local block = {('Status: %s\r\n'):format(STATUS_LINES[res.status])}

  for k, v in pairs(res.headers) do
    table.insert(block, ('%s: %s\r\n'):format(k, v))
  end

  table.insert(block, "\r\n")

  if res.content then
    table.insert(block, res.content)
  end

  return block
end

local function error_page(status)
  return ERROR_PAGE:gsub('%$(%w+)', {
    status = STATUS_LINES[status],
    message = ERROR_MESSAGES[status]
  })
end

function scgi.error_response(status, headers)
  local content = error_page(status)

  headers = headers or {}
  headers['Content-Length'] = #content
  headers['Content-Type'] = 'text/html'

  return scgi.response(status, headers, content)
end

function scgi.response(status, headers, content)
  headers = headers or {}

  return {
    status = status,
    headers = headers,
    content = content
  }
end

return scgi

