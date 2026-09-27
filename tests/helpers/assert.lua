local Assert = {}

function Assert.equal(actual, expected, message)
  if actual ~= expected then
    error(message or string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
  end
end

function Assert.contains(haystack, needle, message)
  if type(haystack) ~= "string" or not string.find(haystack, needle, 1, true) then
    error(message or string.format("expected %q to contain %q", tostring(haystack), tostring(needle)), 2)
  end
end

function Assert.notContains(haystack, needle, message)
  if type(haystack) == "string" and string.find(haystack, needle, 1, true) then
    error(message or string.format("expected %q not to contain %q", haystack, needle), 2)
  end
end

return Assert
