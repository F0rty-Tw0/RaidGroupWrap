local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GroupWrap = ns.GroupWrap or require("RaidGroupWrap.Layout.GroupWrap")
local SavedState = ns.SavedState or require("RaidGroupWrap.Settings.SavedState")
local SliderPanel = ns.SliderPanel or require("RaidGroupWrap.EditMode.SliderPanel")

local ADDON_NAME = "RaidGroupWrap"

local Bootstrap = {}

function Bootstrap.Initialize(saved)
  local db = SavedState.Initialize(saved)
  GroupWrap.Install(db)
  SliderPanel.Install(db, GroupWrap.Wrap)
  return db
end

if type(_G.CreateFrame) == "function" then
  local loader = _G.CreateFrame("Frame")
  loader:RegisterEvent("ADDON_LOADED")
  loader:SetScript("OnEvent", function(self, _event, loadedName)
    if loadedName ~= ADDON_NAME then
      return
    end
    self:UnregisterEvent("ADDON_LOADED")
    _G.RaidGroupWrapDB = Bootstrap.Initialize(_G.RaidGroupWrapDB)
  end)
end

ns.Bootstrap = Bootstrap
return Bootstrap
