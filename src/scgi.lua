local error = error
local pairs = pairs
local table = table
local tonumber = tonumber

local STATUS = {
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
  [405] = 'The requested HTTP method is not supported',
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

local function validate_headers(headers)
	if headers.CONTENT_LENGTH == '' then
		error('SCGI requires CONTENT_LENGTH have a value, even if "0"')
	end

	if headers.SCGI ~= '1' then
		error('request from webserver must have "SCGI" header with value of "1"')
	end

	-- enforce base 10, we should never have CONTENT_LENGTH: 0xFF (lol)
	if not tonumber(headers.CONTENT_LENGTH, 10) then
		error('CONTENT_LENGTH\'s value is not a number')
	end
end

local function parse_headers(request)
  local netsize, scgistart = request:match('^(%d+):()')

	if not netsize then
		error('netstring size not found in SCGI request')
	end

	local head = request:sub(scgistart, scgistart + netsize)
  local headers = {}
  local first_header = true

	for k, v in head:gmatch('(%Z+)%z(%Z*)%z') do
		if headers[k] then
			error('duplicate SCGI header encountered')
		end

    if first_header then
      first_header = false

      if k ~= 'CONTENT_LENGTH' then
        error('SCGI spec mandates CONTENT_LENGTH be the first header')
      end
    end

		headers[k] = v
	end

  return headers
end

local function parse_request(request)
  local headers = parse_headers(request)
  validate_headers(headers)

  if headers.HTTP_ACCEPT_ENCODING then
    headers.HTTP_ACCEPT_ENCODING = split_header(headers.HTTP_ACCEPT_ENCODING)
  end

  return headers
end

local function build_response(status, headers)
  headers = headers or {}

  local block = {('Status: %s'):format(STATUS_LINES[status])}

  for k, v in pairs(headers) do
    table.insert(block, ('%s: %s'):format(k, v))
  end

  table.insert(block, "\r\n")

  return table.concat(block, "\r\n")
end

local function build_error_response(status)
  local error_page = ERROR_PAGE:gsub('%$(%w+)', {
    status = STATUS_LINES[status],
    message = ERROR_MESSAGES[status]
  })

  local headers = build_response(status, {
    ['Content-Type'] = 'text/html',
    ['Content-Length'] = #error_page
  })

  return headers, error_page
end

return {
  STATUS = STATUS,
  parse_request = parse_request,
  build_response = build_response,
  build_error_response = build_error_response
}

