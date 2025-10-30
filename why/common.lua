local ipairs = ipairs
local table = table

function table.contains(needle, haystack)
  for _, v in ipairs(haystack) do
    if v == needle then
      return true
    end
  end

  return false
end

