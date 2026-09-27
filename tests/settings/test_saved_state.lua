local Assert = require("tests.helpers.assert")
local SavedState = require("RaidGroupWrap.Settings.SavedState")

local function perLineFrom(value)
  return SavedState.Initialize({ perLine = value }).perLine
end

local function test_new_install_keeps_blizzard_layout()
  Assert.equal(SavedState.Initialize(nil).perLine, 8)
end

local function test_saved_choice_survives_initialize()
  Assert.equal(perLineFrom(4), 4)
end

local function test_fractional_value_rounds_to_nearest_group()
  Assert.equal(perLineFrom(3.4), 3)
  Assert.equal(perLineFrom(3.5), 4)
end

local function test_out_of_range_value_is_clamped()
  Assert.equal(perLineFrom(0), 1)
  Assert.equal(perLineFrom(-5), 1)
  Assert.equal(perLineFrom(12), 8)
  Assert.equal(perLineFrom(math.huge), 8)
end

local function test_non_number_value_falls_back_to_default()
  Assert.equal(perLineFrom("4"), 8)
  Assert.equal(perLineFrom(0 / 0), 8)
  Assert.equal(SavedState.Initialize("broken").perLine, 8)
end

local function test_unknown_saved_keys_are_dropped()
  Assert.equal(SavedState.Initialize({ perLine = 4, removedSetting = true }).removedSetting, nil)
end

return function()
  test_new_install_keeps_blizzard_layout()
  test_saved_choice_survives_initialize()
  test_fractional_value_rounds_to_nearest_group()
  test_out_of_range_value_is_clamped()
  test_non_number_value_falls_back_to_default()
  test_unknown_saved_keys_are_dropped()
end
