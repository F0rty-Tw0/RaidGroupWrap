local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("RaidGroupWrap.Core.Constants")
local Localization = ns.Localization or require("RaidGroupWrap.Core.Localization")

local MIN_PER_LINE = 1
local ROW_HEIGHT = 32
local ROW_TOP_INSET = 14
local PANEL_HEIGHT = ROW_TOP_INSET * 2 + ROW_HEIGHT * 2
local DOCK_OFFSET_Y = 4
local LABEL_WIDTH = 100
local LABEL_INSET = 20
local SLIDER_WIDTH = 200
local SLIDER_GAP = 5

-- Edit Mode: a small panel docked under the Raid Frames settings dialog.
-- It is NOT a child of the dialog: anything our code adds to or re-lays-out inside
-- Blizzard's dialog taints Edit Mode, and Blizzard's raid/party frame updates then
-- error on secret health values. Parented to UIParent, only anchored to the dialog.
local SliderPanel = {}

local function createPanel(dialog)
  local panel = _G.CreateFrame("Frame", nil, _G.UIParent)
  panel:SetFrameStrata("DIALOG")
  panel:SetHeight(PANEL_HEIGHT)
  panel:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 0, DOCK_OFFSET_Y)
  panel:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, DOCK_OFFSET_Y)
  panel:EnableMouse(true) -- no click-through to the frames underneath
  panel:Hide()

  panel.Border = _G.CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")

  -- Same pieces and sizes as Blizzard's EditModeSettingSliderTemplate, but not that
  -- template itself, because its mixin reports changes to Blizzard's Edit Mode manager.
  panel.Label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
  panel.Label:SetSize(LABEL_WIDTH, ROW_HEIGHT)
  panel.Label:SetJustifyH("LEFT")
  panel.Label:SetPoint("TOPLEFT", LABEL_INSET, -ROW_TOP_INSET)

  panel.Slider = _G.CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
  panel.Slider:SetSize(SLIDER_WIDTH, ROW_HEIGHT)
  panel.Slider:SetPoint("LEFT", panel.Label, "RIGHT", SLIDER_GAP, 0)

  -- Plain UICheckButtonTemplate, not Edit Mode's checkbox template, for the same reason.
  panel.FlipLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
  panel.FlipLabel:SetSize(LABEL_WIDTH, ROW_HEIGHT)
  panel.FlipLabel:SetJustifyH("LEFT")
  panel.FlipLabel:SetPoint("TOPLEFT", panel.Label, "BOTTOMLEFT", 0, 0)

  panel.FlipCheck = _G.CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  panel.FlipCheck:SetPoint("LEFT", panel.FlipLabel, "RIGHT", SLIDER_GAP, 0)
  return panel
end

-- Groups can't move in combat, so the controls are greyed out there. Combat events
-- are registered only while the panel is shown. The event drives the state:
-- PLAYER_REGEN_DISABLED fires before InCombatLockdown() turns true.
local function disableInCombat(panel)
  panel:SetScript("OnShow", function(self)
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
  end)
  panel:SetScript("OnHide", function(self)
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end)
  panel:SetScript("OnEvent", function(self, event)
    local enabled = event == "PLAYER_REGEN_ENABLED"
    self.Slider:SetEnabled(enabled)
    self.FlipCheck:SetEnabled(enabled)
  end)
end

-- onChange runs after the player picks a new groups-per-line value or fill order.
function SliderPanel.Install(db, onChange)
  local container = _G.CompactRaidFrameContainer
  local dialog = _G.EditModeSystemSettingsDialog
  local mixin = _G.MinimalSliderWithSteppersMixin
  local panel = createPanel(dialog)
  disableInCombat(panel)
  local formatters = {
    [mixin.Label.Right] = _G.CreateMinimalSliderFormatter(mixin.Label.Right),
  }

  panel.Slider:RegisterCallback(mixin.Event.OnValueChanged, function(_, value)
    value = math.floor(value + 0.5)
    if value ~= db.perLine then
      db.perLine = value
      onChange()
    end
  end, panel)

  panel.FlipCheck:SetScript("OnClick", function(self)
    db.flipFill = self:GetChecked()
    onChange()
  end)

  _G.hooksecurefunc(dialog, "UpdateSettings", function(self)
    local show = self.attachedToSystem == container and not container:UseCombinedGroups()
    panel:SetShown(show)
    if show then
      local stacked = container:GetSettingValue(_G.Enum.EditModeUnitFrameSetting.RaidGroupDisplayType)
        == _G.Enum.RaidGroupDisplayType.SeparateGroupsHorizontal
      panel.Label:SetText(stacked and Localization.Text("Groups Per Column") or Localization.Text("Groups Per Row"))
      panel.FlipLabel:SetText(stacked and Localization.Text("Fill Rows First") or Localization.Text("Odds / Evens"))
      panel.Slider:Init(db.perLine, MIN_PER_LINE, Constants.MAX_GROUPS, Constants.MAX_GROUPS - MIN_PER_LINE, formatters)
      panel.FlipCheck:SetChecked(db.flipFill)
      local enabled = not _G.InCombatLockdown()
      panel.Slider:SetEnabled(enabled)
      panel.FlipCheck:SetEnabled(enabled)
    end
  end)

  dialog:HookScript("OnHide", function()
    panel:Hide()
  end)
  return panel
end

ns.SliderPanel = SliderPanel
return SliderPanel
