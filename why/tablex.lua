local ipairs = ipairs

local tablex = {}

function tablex.contains(needle, haystack)
  for _, v in ipairs(haystack) do
    if v == needle then
      return true
    end
  end

  return false
end

return tablex

