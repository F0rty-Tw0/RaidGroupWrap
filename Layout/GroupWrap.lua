local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("RaidGroupWrap.Core.Constants")
local GroupGrid = ns.GroupGrid or require("RaidGroupWrap.Layout.GroupGrid")

local ipairs = ipairs
local max = math.max
local min = math.min
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

local MAX_RAID_MEMBERS = 40
local MAX_PARTY_PETS = 4
local ORPHAN = 0

-- Pet unit -> raid index of its owner. 0: no raid owner (solo / party pets,
-- shown in the Edit Mode preview outside a raid). Built once, no string work per layout.
local PET_RAID_INDEX = { pet = 0 }
for i = 1, MAX_RAID_MEMBERS do
  PET_RAID_INDEX["raidpet" .. i] = i
end
for i = 1, MAX_PARTY_PETS do
  PET_RAID_INDEX["partypet" .. i] = 0
end

local container, db, events
-- Reused every layout, no garbage.
local groups, ordered, sizes, points = {}, {}, {}, {}
local pets, petSlots, slotById = {}, {}, {}

local function collectFrames()
  _G.wipe(groups)
  _G.wipe(pets)
  for _, object in ipairs(container.flowFrames) do
    if type(object) == "table" then
      if object.isFlowGroup then
        groups[#groups + 1] = object
      elseif PET_RAID_INDEX[object.unit] then
        pets[#pets + 1] = object
      end
    end
  end
end

-- Odds / Evens: 1-3-5-7 then 2-4-6-8 in Blizzard's order, then wrapped as usual.
local function orderOddsThenEvens()
  _G.wipe(ordered)
  for first = 1, 2 do
    for i = first, #groups, 2 do
      ordered[#ordered + 1] = groups[i]
    end
  end
  groups, ordered = ordered, groups
end

-- petSlots[i] = slot in `groups` of pet i's owner group, or ORPHAN.
-- Run after any reordering, so slots match the final order.
-- Not wrapping (slider moved to 8): every pet is an orphan, which is Blizzard's spot.
local function assignPets(wrapping)
  _G.wipe(slotById)
  for slot, group in ipairs(groups) do
    slotById[group:GetID()] = slot
  end
  for i, pet in ipairs(pets) do
    local slot = ORPHAN
    local index = PET_RAID_INDEX[pet.unit]
    if wrapping and index > 0 then
      local _, _, subgroup = _G.GetRaidRosterInfo(index)
      slot = subgroup and slotById[subgroup] or ORPHAN
    end
    petSlots[i] = slot
  end
end

-- Owned pets sit under their group: stacked when groups sit side by side,
-- one row when groups stack. The group's line grows to fit them.
local function growForPets(sideBySide)
  for i, pet in ipairs(pets) do
    local size = sizes[petSlots[i]]
    if size then
      local width, height = pet:GetSize()
      if sideBySide then
        size.petsWidth, size.petsHeight = max(size.petsWidth, width), size.petsHeight + height
      else
        size.petsWidth, size.petsHeight = size.petsWidth + width, max(size.petsHeight, height)
      end
    end
  end
  for _, size in ipairs(sizes) do
    size.width = max(size.ownWidth, size.petsWidth)
    size.height = size.ownHeight + size.petsHeight
  end
end

local function measureGroups(sideBySide, wrapping)
  for i, group in ipairs(groups) do
    local size = sizes[i] or {}
    size.ownWidth, size.ownHeight = group:GetSize()
    size.width, size.height = size.ownWidth, size.ownHeight
    size.petsWidth, size.petsHeight, size.petCursor = 0, 0, 0
    sizes[i] = size
  end
  for i = #sizes, #groups + 1, -1 do
    sizes[i] = nil
  end
  if #pets > 0 then
    assignPets(wrapping)
    growForPets(sideBySide)
  end
end

-- Anchored from the group's new spot and own size, never a pet's old anchor,
-- so wrapping twice gives the same result.
local function placeOwnedPets(sideBySide)
  for i, pet in ipairs(pets) do
    local slot = petSlots[i]
    local size, point = sizes[slot], points[slot]
    if size then
      local width, height = pet:GetSize()
      local x, y = point.x, point.y - size.ownHeight
      if sideBySide then
        x, y = x + (size.ownWidth - width) / 2, y - size.petCursor -- centred like members
        size.petCursor = size.petCursor + height
      else
        x = x + size.petCursor
        size.petCursor = size.petCursor + width
      end
      pet:ClearAllPoints()
      pet:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
    end
  end
end

-- Orphans (no shown owner group) get one line past the block, the way Blizzard's
-- flow lines up pets after the last group. Never wrapped. Returns the grown edges.
local function placeOrphanPets(sideBySide, right, bottom, x0, y0, gap)
  local x, y, spacing
  if sideBySide then
    x, y, spacing = right + gap, y0, container.flowVerticalSpacing or 0
  else
    x, y, spacing = x0, bottom - gap, container.flowHorizontalSpacing or 0
  end
  for i, pet in ipairs(pets) do
    if petSlots[i] == ORPHAN then
      local width, height = pet:GetSize()
      pet:ClearAllPoints()
      pet:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
      right, bottom = max(right, x + width), min(bottom, y - height)
      if sideBySide then
        y = y - height - spacing
      else
        x = x + width + spacing
      end
    end
  end
  return right, bottom
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

  collectFrames()
  if #groups == 0 then
    return
  end
  local wrapping = db.perLine < Constants.MAX_GROUPS -- off at 8: Blizzard's order and pet spot
  if db.flipFill and wrapping then
    orderOddsThenEvens()
  end

  -- Flow "vertical" = Separate Groups (Vertical): groups sit side by side, so a line is a row.
  -- Flow "horizontal" = Separate Groups (Horizontal): groups stack downward, so a line is a column.
  local sideBySide = container.flowOrientation == "vertical"
  measureGroups(sideBySide, wrapping)
  local gap
  if sideBySide then
    gap = container.flowHorizontalSpacing or 0
  else
    gap = container.flowVerticalSpacing or 0
  end

  local _, _, _, x0, y0 = groups[1]:GetPoint(1)
  local _, right, bottom = GroupGrid.Layout(sizes, db.perLine, sideBySide, x0, y0, gap, points)
  for i, group in ipairs(groups) do
    group:ClearAllPoints()
    group:SetPoint("TOPLEFT", container, "TOPLEFT", points[i].x, points[i].y)
  end
  if #pets > 0 then
    placeOwnedPets(sideBySide)
    right, bottom = placeOrphanPets(sideBySide, right, bottom, x0, y0, gap)
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
