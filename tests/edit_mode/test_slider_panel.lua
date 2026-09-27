local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local SliderPanel = require("RaidGroupWrap.EditMode.SliderPanel")

local function setup(perLine)
  local W = Wow.Install()
  local db = { perLine = perLine or 8 }
  local changes = { count = 0 }
  local panel = SliderPanel.Install(db, function()
    changes.count = changes.count + 1
  end)
  return W, panel, db, changes
end

local function openRaidFrameSettings(W)
  W.dialog.attachedToSystem = W.container
  W.callHooked(W.dialog, "UpdateSettings", W.dialog)
end

local function assertPoint(frame, index, ...)
  local expected = { ... }
  local actual = { frame:GetPoint(index) }
  for i = 1, #expected do
    Assert.equal(actual[i], expected[i], "point " .. index .. " arg " .. i)
  end
end

local function test_panel_is_parented_to_uiparent_not_the_dialog()
  local W, panel = setup()
  Assert.equal(panel:GetParent(), _G.UIParent)
  Assert.equal(panel:GetParent() ~= W.dialog and panel:GetParent() ~= W.dialog.Settings, true)
end

local function test_panel_docks_under_the_dialog()
  local W, panel = setup()
  Assert.equal(panel:GetFrameStrata(), "DIALOG")
  Assert.equal(panel:GetHeight(), 60)
  assertPoint(panel, 1, "TOPLEFT", W.dialog, "BOTTOMLEFT", 0, 4)
  assertPoint(panel, 2, "TOPRIGHT", W.dialog, "BOTTOMRIGHT", 0, 4)
  Assert.equal(panel:IsMouseEnabled(), true, "no click-through")
  Assert.equal(panel:IsShown(), false, "hidden until Edit Mode asks")
end

local function test_panel_has_translucent_dialog_border()
  local W, panel = setup()
  Assert.equal(panel.Border:GetParent(), panel)
  Assert.equal(W.state(panel.Border).template, "DialogBorderTranslucentTemplate")
end

local function test_label_and_slider_match_blizzard_slider_rows()
  local W, panel = setup()
  Assert.equal(W.state(panel.Label).template, "GameFontHighlightMedium")
  Assert.equal(W.state(panel.Label).width, 100)
  Assert.equal(W.state(panel.Label).height, 32)
  Assert.equal(W.state(panel.Label).justifyH, "LEFT")
  assertPoint(panel.Label, 1, "LEFT", 20, 0)
  Assert.equal(W.state(panel.Slider).template, "MinimalSliderWithSteppersTemplate")
  Assert.equal(W.state(panel.Slider).width, 200)
  Assert.equal(W.state(panel.Slider).height, 32)
  assertPoint(panel.Slider, 1, "LEFT", panel.Label, "RIGHT", 5, 0)
end

local function test_raid_frame_settings_show_the_slider_with_saved_value()
  local W, panel = setup(3)
  openRaidFrameSettings(W)
  Assert.equal(panel:IsShown(), true)
  Assert.equal(panel.Label:GetText(), "Groups Per Row")
  local init = W.state(panel.Slider).init
  Assert.equal(init.value, 3)
  Assert.equal(init.min, 1)
  Assert.equal(init.max, 8)
  Assert.equal(init.steps, 7)
  Assert.equal(type(init.formatters[_G.MinimalSliderWithSteppersMixin.Label.Right]), "function")
end

local function test_horizontal_groups_label_the_slider_per_column()
  local W, panel = setup()
  W.raidGroupDisplayType = _G.Enum.RaidGroupDisplayType.SeparateGroupsHorizontal
  openRaidFrameSettings(W)
  Assert.equal(panel.Label:GetText(), "Groups Per Column")
end

local function test_other_edit_mode_systems_hide_the_panel()
  local W, panel = setup()
  openRaidFrameSettings(W)
  W.dialog.attachedToSystem = {}
  W.callHooked(W.dialog, "UpdateSettings", W.dialog)
  Assert.equal(panel:IsShown(), false)
end

local function test_combined_groups_hide_the_panel()
  local W, panel = setup()
  W.combinedGroups = true
  openRaidFrameSettings(W)
  Assert.equal(panel:IsShown(), false)
end

local function test_closing_the_dialog_hides_the_panel()
  local W, panel = setup()
  openRaidFrameSettings(W)
  W.fireScript(W.dialog, "OnHide")
  Assert.equal(panel:IsShown(), false)
end

local function test_slider_change_saves_rounded_value_and_rewraps()
  local W, panel, db, changes = setup(8)
  W.fireCallback(panel.Slider, _G.MinimalSliderWithSteppersMixin.Event.OnValueChanged, 3.6)
  Assert.equal(db.perLine, 4)
  Assert.equal(changes.count, 1)
end

local function test_unchanged_slider_value_does_nothing()
  local W, panel, db, changes = setup(4)
  W.fireCallback(panel.Slider, _G.MinimalSliderWithSteppersMixin.Event.OnValueChanged, 4.2)
  Assert.equal(db.perLine, 4)
  Assert.equal(changes.count, 0)
end

local function test_panel_only_hooks_the_dialog()
  local W = Wow.Install()
  local dialogBefore = W.snapshot(W.dialog)
  local settingsBefore = W.snapshot(W.dialog.Settings)
  SliderPanel.Install({ perLine = 8 }, function() end)
  openRaidFrameSettings(W)
  W.fireScript(W.dialog, "OnHide")
  W.dialog.attachedToSystem = nil
  Assert.equal(W.changedKeys(W.dialog, dialogBefore), "")
  Assert.equal(W.changedKeys(W.dialog.Settings, settingsBefore), "")
  Assert.equal(#W.secureHooks[W.dialog].UpdateSettings, 1)
  Assert.equal(W.state(W.dialog).scripts.OnHide, nil, "HookScript, not SetScript")
  Assert.equal(#W.state(W.dialog).hooks.OnHide, 1)
  Assert.equal(#W.forbiddenCalls, 0, table.concat(W.forbiddenCalls, ","))
end

return function()
  test_panel_is_parented_to_uiparent_not_the_dialog()
  test_panel_docks_under_the_dialog()
  test_panel_has_translucent_dialog_border()
  test_label_and_slider_match_blizzard_slider_rows()
  test_raid_frame_settings_show_the_slider_with_saved_value()
  test_horizontal_groups_label_the_slider_per_column()
  test_other_edit_mode_systems_hide_the_panel()
  test_combined_groups_hide_the_panel()
  test_closing_the_dialog_hides_the_panel()
  test_slider_change_saves_rounded_value_and_rewraps()
  test_unchanged_slider_value_does_nothing()
  test_panel_only_hooks_the_dialog()
end
