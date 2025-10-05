#!/usr/bin/env lua

local error = error
local pairs = pairs
local table = table
local tonumber = tonumber

local STATUS = {
  [200] = 'Ok',
  [400] = 'Bad Request',
  [404] = 'Not Found',
  [500] = 'Internal Server Error'
}

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

local function parse(request)
  local headers = parse_headers(request)
  validate_headers(headers)
  return headers
end

local function build_header(status, headers)
  local block = {('Status: %i %s'):format(status, STATUS[status])}

  for k, v in pairs(headers) do
    table.insert(block, ('%s: %s'):format(k, v))
  end

  return table.concat(block, "\r\n") .. "\r\n\r\n"
end

return {
  parse = parse,
  build_header = build_header
}

