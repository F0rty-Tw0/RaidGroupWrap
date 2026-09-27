local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local W = Wow.Install()

local groups = {}
for i = 1, 8 do
  groups[i] = W.newGroup(72, 180, (i - 1) * 72, 0)
  W.container.flowFrames[i] = groups[i]
end

_G.RaidGroupWrapDB = { perLine = 3.6, removed = 1 }
require("RaidGroupWrap.Bootstrap")

local function loader()
  for _, frame in ipairs(W.frames) do
    if frame:IsEventRegistered("ADDON_LOADED") then
      return frame
    end
  end
end

local function sliderPanel()
  for _, frame in ipairs(W.frames) do
    if frame.Slider then
      return frame
    end
  end
end

local function test_nothing_is_installed_before_addon_loaded()
  Assert.equal(W.calls.hooksecurefunc, nil)
  Assert.equal(sliderPanel(), nil)
end

local function test_other_addons_loading_are_ignored()
  W.fireEvent(loader(), "ADDON_LOADED", "SomethingElse")
  Assert.equal(_G.RaidGroupWrapDB.removed, 1)
end

local function test_addon_loaded_initializes_everything_once()
  local frame = loader()
  W.fireEvent(frame, "ADDON_LOADED", "RaidGroupWrap")
  Assert.equal(_G.RaidGroupWrapDB.perLine, 4, "saved value rounded")
  Assert.equal(_G.RaidGroupWrapDB.removed, nil, "unknown key dropped")
  Assert.equal(frame:IsEventRegistered("ADDON_LOADED"), false, "unregistered after load")
  Assert.equal(#W.secureHooks[_G].FlowContainer_DoLayout, 1, "layout hook installed")
  Assert.equal(sliderPanel() ~= nil, true, "Edit Mode panel created")
end

local function test_loading_does_not_move_groups_by_itself()
  local _point, _relativeTo, _relativePoint, x = groups[5]:GetPoint(1)
  Assert.equal(x, 288)
end

local function test_slider_change_is_saved_and_rewraps_groups()
  local panel = sliderPanel()
  W.fireCallback(panel.Slider, _G.MinimalSliderWithSteppersMixin.Event.OnValueChanged, 2)
  Assert.equal(_G.RaidGroupWrapDB.perLine, 2)
  local _point, _relativeTo, _relativePoint, x, y = groups[3]:GetPoint(1)
  Assert.equal(x, 0)
  Assert.equal(y, -180)
end

return function()
  test_nothing_is_installed_before_addon_loaded()
  test_other_addons_loading_are_ignored()
  test_addon_loaded_initializes_everything_once()
  test_loading_does_not_move_groups_by_itself()
  test_slider_change_is_saved_and_rewraps_groups()
end
