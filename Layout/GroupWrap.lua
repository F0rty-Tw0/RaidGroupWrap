local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("RaidGroupWrap.Core.Constants")
local GroupGrid = ns.GroupGrid or require("RaidGroupWrap.Layout.GroupGrid")

local ceil = math.ceil
local ipairs = ipairs
local type = type

-- Blizzard's FlowContainer gives every raid group its own line (isFlowGroup),
-- so groups are re-anchored right after Blizzard lays them out. No OnUpdate,
-- no timers: code only runs when Blizzard itself re-lays out the raid frames.
--
-- Taint: only a secure hook touches Blizzard code. Never assign fields on
-- Blizzard frames and never call Blizzard Lua methods that write fields
-- (container:Layout(), TryUpdate, FlowContainer_* setters); only C API
-- calls (ClearAllPoints, SetPoint, SetSize) move frames.
local GroupWrap = {}

local container, db, events
-- Reused every layout, no garbage.
local groups, sizes, points = {}, {}, {}

local function collectGroups()
  _G.wipe(groups)
  for _, object in ipairs(container.flowFrames) do
    if type(object) == "table" and object.isFlowGroup then
      groups[#groups + 1] = object
    end
  end
end

local function measureGroups()
  for i, group in ipairs(groups) do
    local size = sizes[i] or {}
    size.width, size.height = group:GetSize()
    sizes[i] = size
  end
  for i = #sizes, #groups + 1, -1 do
    sizes[i] = nil
  end
end

function GroupWrap.Wrap()
  if container:GetGroupMode() ~= "discrete" then
    return -- "Combine Groups" already has Blizzard's own Row Size setting
  end
  if _G.InCombatLockdown() then
    -- Group frames hold secure unit buttons, so they can't move in combat. Retry after.
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  collectGroups()
  if #groups == 0 then
    return
  end
  measureGroups()

  -- Flow "vertical" = Separate Groups (Vertical): groups sit side by side, so a line is a row.
  -- Flow "horizontal" = Separate Groups (Horizontal): groups stack downward, so a line is a column.
  local sideBySide = container.flowOrientation == "vertical"
  local gap
  if sideBySide then
    gap = container.flowHorizontalSpacing or 0
  else
    gap = container.flowVerticalSpacing or 0
  end

  -- Flip fill: groups fill down each column first (1-3-5-7 over 2-4-6-8), or across each
  -- row first when stacked. That is the other orientation's layout with lines of
  -- groups / perLine rounded up (rows side by side, columns when stacked).
  local perLine = db.perLine
  if db.flipFill then
    perLine, sideBySide = ceil(#groups / perLine), not sideBySide
  end

  -- ponytail: only groups move; raid pets (Display Pets, off by default) keep Blizzard's spot.
  local _, _, _, x0, y0 = groups[1]:GetPoint(1)
  local _, right, bottom = GroupGrid.Layout(sizes, perLine, sideBySide, x0, y0, gap, points)
  for i, group in ipairs(groups) do
    group:ClearAllPoints()
    group:SetPoint("TOPLEFT", container, "TOPLEFT", points[i].x, points[i].y)
  end

  -- Fit the Edit Mode box to the wrapped block. SetSize, not container:Layout(),
  -- because Layout() writes Lua fields that would taint Blizzard's raid frame code.
  container:SetSize(right, -bottom)
end

function GroupWrap.Install(savedDb)
  db = savedDb
  container = _G.CompactRaidFrameContainer

  -- Only PLAYER_REGEN_ENABLED, and only while a wrap waits for combat to end.
  events = _G.CreateFrame("Frame")
  events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    GroupWrap.Wrap()
  end)

  _G.hooksecurefunc("FlowContainer_DoLayout", function(flow)
    if flow == container and not flow.flowPauseUpdates and db.perLine < Constants.MAX_GROUPS then
      GroupWrap.Wrap()
    end
  end)
end

ns.GroupWrap = GroupWrap
return GroupWrap
