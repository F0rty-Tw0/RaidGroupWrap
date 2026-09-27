-- Minimal fake WoW API. Wow.Install() rebuilds every global from scratch and
-- returns the state table `W`; tests drive combat, raid groups and Edit Mode
-- through it. W.calls[name] counts calls to any API defined with def().
--
-- Widget state set through C-API-like methods (points, size, shown, ...)
-- lives in widget._stub, never in other top-level fields, so a test can
-- snapshot a Blizzard frame's fields and prove the addon wrote none.

local Wow = {}

local unpack = table.unpack or unpack

local function newWidget(W, frameType, name, parent, template)
  local stub = {
    frameType = frameType,
    parent = parent,
    template = template,
    scripts = {},
    hooks = {},
    events = {},
    callbacks = {},
    points = {},
    shown = true,
  }
  local widget = { _stub = stub }

  function widget:SetPoint(...)
    table.insert(stub.points, { ... })
  end
  function widget:GetPoint(index)
    local point = stub.points[index or 1]
    if point then
      return unpack(point)
    end
  end
  function widget:GetNumPoints()
    return #stub.points
  end
  function widget:ClearAllPoints()
    stub.points = {}
  end
  function widget:SetSize(width, height)
    stub.width, stub.height = width, height
  end
  function widget:GetSize()
    return stub.width or 0, stub.height or 0
  end
  function widget:SetHeight(height)
    stub.height = height
  end
  function widget:GetHeight()
    return stub.height or 0
  end
  function widget:SetFrameStrata(strata)
    stub.strata = strata
  end
  function widget:GetFrameStrata()
    return stub.strata
  end
  function widget:EnableMouse(enabled)
    stub.mouse = enabled and true or false
  end
  function widget:IsMouseEnabled()
    return stub.mouse == true
  end
  function widget:SetJustifyH(justify)
    stub.justifyH = justify
  end
  function widget:GetParent()
    return stub.parent
  end
  function widget:SetScript(script, fn)
    stub.scripts[script] = fn
  end
  function widget:GetScript(script)
    return stub.scripts[script]
  end
  function widget:HookScript(script, fn)
    stub.hooks[script] = stub.hooks[script] or {}
    table.insert(stub.hooks[script], fn)
  end
  function widget:RegisterEvent(event)
    stub.events[event] = true
  end
  function widget:UnregisterEvent(event)
    stub.events[event] = nil
  end
  function widget:IsEventRegistered(event)
    return stub.events[event] == true
  end
  -- Like WoW, a visibility change runs OnShow / OnHide (script, then hooks).
  function widget:SetShown(shown)
    shown = shown and true or false
    if stub.shown == shown then
      return
    end
    stub.shown = shown
    local script = shown and "OnShow" or "OnHide"
    if stub.scripts[script] then
      stub.scripts[script](widget)
    end
    for _, fn in ipairs(stub.hooks[script] or {}) do
      fn(widget)
    end
  end
  function widget:Show()
    widget:SetShown(true)
  end
  function widget:Hide()
    widget:SetShown(false)
  end
  function widget:SetEnabled(enabled)
    stub.enabled = enabled and true or false
  end
  function widget:IsEnabled()
    return stub.enabled ~= false
  end
  function widget:IsShown()
    return stub.shown
  end
  function widget:SetText(text)
    stub.text = text
  end
  function widget:GetText()
    return stub.text
  end
  function widget:CreateFontString(fontName, layer, fontTemplate)
    return newWidget(W, "FontString", fontName, widget, fontTemplate)
  end
  -- CallbackRegistry (MinimalSliderWithSteppersTemplate): fn(owner, ...).
  function widget:RegisterCallback(event, fn, owner)
    stub.callbacks[event] = { fn = fn, owner = owner }
  end
  -- MinimalSliderWithSteppersMixin:Init(value, min, max, steps, formatters).
  function widget:Init(value, minValue, maxValue, steps, formatters)
    stub.init = { value = value, min = minValue, max = maxValue, steps = steps, formatters = formatters }
  end

  if name then
    rawset(_G, name, widget)
  end
  table.insert(W.frames, widget)
  return widget
end

-- Test-side drivers; they read or poke widget._stub, never other fields.
local function installDrivers(W)
  function W.state(widget)
    return widget._stub
  end

  function W.fireScript(widget, script, ...)
    local stub = widget._stub
    if stub.scripts[script] then
      stub.scripts[script](widget, ...)
    end
    for _, fn in ipairs(stub.hooks[script] or {}) do
      fn(widget, ...)
    end
  end

  function W.fireEvent(widget, event, ...)
    local stub = widget._stub
    if stub.events[event] and stub.scripts.OnEvent then
      stub.scripts.OnEvent(widget, event, ...)
    end
  end

  function W.fireCallback(widget, event, ...)
    local callback = widget._stub.callbacks[event]
    if callback then
      callback.fn(callback.owner, ...)
    end
  end

  -- Calls target[name] the way Blizzard would, then every secure hook on it.
  function W.callHooked(target, name, ...)
    target[name](...)
    for _, hook in ipairs(W.secureHooks[target] and W.secureHooks[target][name] or {}) do
      hook(...)
    end
  end

  function W.snapshot(t)
    local copy = {}
    for key, value in pairs(t) do
      copy[key] = value
    end
    return copy
  end

  -- Keys whose value differs between `t` and an earlier W.snapshot(t).
  function W.changedKeys(t, snapshot)
    local changed = {}
    for key, value in pairs(t) do
      if snapshot[key] ~= value then
        changed[#changed + 1] = tostring(key)
      end
    end
    for key in pairs(snapshot) do
      if t[key] == nil then
        changed[#changed + 1] = tostring(key)
      end
    end
    table.sort(changed)
    return table.concat(changed, ",")
  end

  -- A raid group frame from Blizzard's flow layout, at its original spot.
  function W.newGroup(width, height, x, y)
    local group = newWidget(W, "Frame")
    group.isFlowGroup = true
    group:SetSize(width, height)
    group:SetPoint("TOPLEFT", W.container, "TOPLEFT", x or 0, y or 0)
    return group
  end
end

local function forbidden(W, label)
  return function()
    W.forbiddenCalls[#W.forbiddenCalls + 1] = label
    error(label .. " must never be called (taints Blizzard code)")
  end
end

-- CompactRaidFrameContainer: Separate Groups (Vertical) with no spacing.
local function installContainer(W)
  local container = newWidget(W, "Frame", "CompactRaidFrameContainer", _G.UIParent)
  container.flowFrames = {}
  container.flowOrientation = "vertical"
  container.flowHorizontalSpacing = 0
  container.flowVerticalSpacing = 0
  function container:GetGroupMode()
    return W.groupMode
  end
  function container:UseCombinedGroups()
    return W.combinedGroups == true
  end
  function container:GetSettingValue(setting)
    if setting == _G.Enum.EditModeUnitFrameSetting.RaidGroupDisplayType then
      return W.raidGroupDisplayType
    end
  end
  container.Layout = forbidden(W, "CompactRaidFrameContainer:Layout")
  container.TryUpdate = forbidden(W, "CompactRaidFrameContainer:TryUpdate")
  W.container = container
end

local function installDialog(W)
  local dialog = newWidget(W, "Frame", "EditModeSystemSettingsDialog", _G.UIParent)
  dialog.Settings = newWidget(W, "Frame", nil, dialog)
  dialog.Settings.Layout = forbidden(W, "EditModeSystemSettingsDialog.Settings:Layout")
  function dialog:UpdateSettings() end
  W.dialog = dialog

  _G.EditModeManagerFrame = {
    UpdateRaidContainerFlow = forbidden(W, "EditModeManagerFrame:UpdateRaidContainerFlow"),
  }
end

function Wow.Install()
  local W = { calls = {}, frames = {}, secureHooks = {}, forbiddenCalls = {}, groupMode = "discrete" }

  local function def(name, fn)
    rawset(_G, name, function(...)
      W.calls[name] = (W.calls[name] or 0) + 1
      return fn(...)
    end)
  end
  W.def = def

  rawset(_G, "Enum", {
    EditModeUnitFrameSetting = { RaidGroupDisplayType = 0 },
    RaidGroupDisplayType = {
      SeparateGroupsVertical = 0,
      SeparateGroupsHorizontal = 1,
      CombineGroupsVertical = 2,
      CombineGroupsHorizontal = 3,
    },
  })
  W.raidGroupDisplayType = _G.Enum.RaidGroupDisplayType.SeparateGroupsVertical

  rawset(_G, "MinimalSliderWithSteppersMixin", {
    Label = { Right = 3 },
    Event = { OnValueChanged = "OnValueChanged" },
  })

  def("CreateFrame", function(frameType, name, parent, template)
    return newWidget(W, frameType, name, parent, template)
  end)
  def("CreateMinimalSliderFormatter", function(labelType)
    return function(value)
      return tostring(value) .. "@" .. tostring(labelType)
    end
  end)
  -- Records hooks instead of replacing the field; W.callHooked runs them.
  def("hooksecurefunc", function(target, name, hook)
    if type(target) == "string" then
      target, name, hook = _G, target, name
    end
    assert(type(target[name]) == "function", "hooksecurefunc: no function " .. tostring(name))
    W.secureHooks[target] = W.secureHooks[target] or {}
    W.secureHooks[target][name] = W.secureHooks[target][name] or {}
    table.insert(W.secureHooks[target][name], hook)
  end)
  def("InCombatLockdown", function()
    return W.inCombat == true
  end)
  def("wipe", function(t)
    for key in pairs(t) do
      t[key] = nil
    end
    return t
  end)
  rawset(_G, "FlowContainer_DoLayout", function() end)

  newWidget(W, "Frame", "UIParent")
  installDrivers(W)
  installContainer(W)
  installDialog(W)
  return W
end

return Wow
