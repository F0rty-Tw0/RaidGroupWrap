local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("RaidGroupWrap.Core.Constants")

local MIN_PER_LINE = 1

local SavedState = {}

-- Groups per line as a whole number from 1 to MAX_GROUPS; anything else in
-- the saved file (hand edits, old versions) falls back to Blizzard's layout.
local function normalizePerLine(value)
  if type(value) ~= "number" or value ~= value then
    return Constants.MAX_GROUPS
  end
  local rounded = math.floor(value + 0.5)
  return math.max(MIN_PER_LINE, math.min(Constants.MAX_GROUPS, rounded))
end

-- Returns the account-wide settings table. Keys no longer known are dropped
-- so the file never grows.
function SavedState.Initialize(saved)
  saved = type(saved) == "table" and saved or {}
  return { perLine = normalizePerLine(saved.perLine) }
end

ns.SavedState = SavedState
return SavedState
