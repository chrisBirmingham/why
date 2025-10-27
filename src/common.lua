local ipairs = ipairs
local pairs = pairs

function table.merge(t1, t2)
  for k, v in pairs(t2) do
    t1[k] = v
  end
end

function table.contains(needle, haystack)
  for _, v in ipairs(haystack) do
    if v == needle then
      return true
    end
  end

  return false
end

function string:endswith(ending)                                               
  return self:sub(-#ending) == ending
end

