local error = error
local pairs = pairs
local table = table
local tonumber = tonumber

local scgi = {}
local error_pages = {}

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

function scgi.validate_request(request)
  -- enforce base 10, we should never have CONTENT_LENGTH: 0xFF (lol)
  if not tonumber(request.CONTENT_LENGTH, 10) then
    error('CONTENT_LENGTH header value is not a number')
  end

  if not request.SCGI then
    error('Missing SCGI header')
  end

  if request.SCGI ~= '1' then
    error('SCGI header value is not 1')
  end
end

function scgi.parse_request(request)
  local netsize, scgistart = request:match('^(%d+):()')

  if not netsize then
    error('Missing starting netstring')
  end

  local head = request:sub(scgistart, scgistart + netsize)
  local headers = {}
  local first_header = true

  for k, v in head:gmatch('(%Z+)%z(%Z*)%z') do
    if headers[k] then
      error('Duplicate SCGI header encountered')
    end

    if first_header then
      first_header = false

      if k ~= 'CONTENT_LENGTH' then
        error('CONTENT_LENGTH was not the first header')
      end
    end

    headers[k] = v
  end

  if headers.HTTP_ACCEPT_ENCODING then
    headers.HTTP_ACCEPT_ENCODING = split_header(headers.HTTP_ACCEPT_ENCODING)
  end

  return headers
end

function scgi.response_headers(res)
  local block = {('Status: %s'):format(STATUS_LINES[res.status])}

  for k, v in pairs(res.headers) do
    table.insert(block, ('%s: %s'):format(k, v))
  end

  table.insert(block, "\r\n")

  return table.concat(block, "\r\n")
end

function scgi.error_page(status)
  if error_pages[status] then
    return error_pages[status]
  end

  local page = ERROR_PAGE:gsub('%$(%w+)', {
    status = STATUS_LINES[status],
    message = ERROR_MESSAGES[status]
  })

  error_pages[status] = page
  return page
end

function scgi.response(status, headers)
  headers = headers or {}

  return {
    status = status,
    headers = headers
  }
end

return scgi

