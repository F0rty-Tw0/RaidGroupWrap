local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ipairs = ipairs
local max = math.max
local min = math.min

local GroupGrid = {}

-- Places groups in lines of `perLine`, starting at TOPLEFT offset (x0, y0).
-- sideBySide: groups sit next to each other and a line is a row that wraps
-- downward; otherwise groups stack downward and a line is a column that wraps
-- to the right. A line is as tall (or wide) as its biggest group.
--
-- sizes: { { width =, height = }, ... } in flow order.
-- out (optional): reused result table; entries 1..#sizes are overwritten.
-- Returns out ({ { x =, y = }, ... } TOPLEFT offsets), right, bottom.
function GroupGrid.Layout(sizes, perLine, sideBySide, x0, y0, gap, out)
  out = out or {}
  local x, y, lineSize = x0, y0, 0
  local right, bottom = x0, y0
  for i, size in ipairs(sizes) do
    if i > 1 and (i - 1) % perLine == 0 then
      if sideBySide then
        x, y = x0, y - lineSize - gap
      else
        x, y = x + lineSize + gap, y0
      end
      lineSize = 0
    end

    local point = out[i] or {}
    point.x, point.y = x, y
    out[i] = point

    local width, height = size.width, size.height
    right, bottom = max(right, x + width), min(bottom, y - height)
    if sideBySide then
      x = x + width + gap
      lineSize = max(lineSize, height)
    else
      y = y - height - gap
      lineSize = max(lineSize, width)
    end
  end
  return out, right, bottom
end

ns.GroupGrid = GroupGrid
return GroupGrid
