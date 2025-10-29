local ipairs = ipairs

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

