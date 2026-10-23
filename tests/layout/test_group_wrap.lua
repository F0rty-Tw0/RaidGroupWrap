local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local GroupWrap = require("RaidGroupWrap.Layout.GroupWrap")

local GROUP_WIDTH, GROUP_HEIGHT = 72, 180

-- Blizzard's default Separate Groups (Vertical) look: 8 groups side by side,
-- a "linebreak" marker between them, and a non-group frame with no unit at the end.
local function setup(perLine, flipFill)
  local W = Wow.Install()
  local groups = {}
  for i = 1, 8 do
    groups[i] = W.newGroup(GROUP_WIDTH, GROUP_HEIGHT, (i - 1) * GROUP_WIDTH, 0)
    W.container.flowFrames[#W.container.flowFrames + 1] = groups[i]
    W.container.flowFrames[#W.container.flowFrames + 1] = "linebreak"
  end
  local pet = W.newGroup(72, 36, 0, -180)
  pet.isFlowGroup = nil
  W.container.flowFrames[#W.container.flowFrames + 1] = pet
  local db = { perLine = perLine, flipFill = flipFill }
  GroupWrap.Install(db)
  return W, groups, db, pet
end

-- The addon's own event frame: the only frame with an OnEvent script.
local function eventFrame(W)
  for _, frame in ipairs(W.frames) do
    if W.state(frame).scripts.OnEvent then
      return frame
    end
  end
end

local function assertAt(W, group, x, y)
  local point, relativeTo, relativePoint, gx, gy = group:GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, W.container)
  Assert.equal(relativePoint, "TOPLEFT")
  Assert.equal(gx, x, "x")
  Assert.equal(gy, y, "y")
  Assert.equal(group:GetNumPoints(), 1, "old anchors cleared")
end

local function test_wrap_moves_groups_into_rows_of_per_line()
  local W, groups = setup(4)
  GroupWrap.Wrap()
  assertAt(W, groups[4], 216, 0)
  assertAt(W, groups[5], 0, -180)
  assertAt(W, groups[8], 216, -180)
end

local function test_container_is_resized_to_the_wrapped_block()
  local W = setup(4)
  GroupWrap.Wrap()
  local width, height = W.container:GetSize()
  Assert.equal(width, 288)
  Assert.equal(height, 360)
end

local function test_non_pet_frames_keep_blizzard_position()
  local W, _groups, _db, pet = setup(4)
  GroupWrap.Wrap()
  local _point, _relativeTo, _relativePoint, x, y = pet:GetPoint(1)
  Assert.equal(x, 0)
  Assert.equal(y, -180)
end

local function test_combined_groups_mode_is_left_alone()
  local W, groups = setup(4)
  W.groupMode = "flush"
  GroupWrap.Wrap()
  assertAt(W, groups[5], 288, 0)
  Assert.equal(W.container:GetSize(), 0, "container not resized")
end

local function test_no_groups_does_nothing()
  local W = setup(4)
  W.container.flowFrames = {}
  GroupWrap.Wrap()
  Assert.equal(W.container:GetSize(), 0, "container not resized")
end

local function test_side_by_side_rows_use_horizontal_spacing()
  local W, groups = setup(4)
  W.container.flowHorizontalSpacing = 10
  W.container.flowVerticalSpacing = 99
  GroupWrap.Wrap()
  assertAt(W, groups[2], 82, 0)
  assertAt(W, groups[5], 0, -190)
end

local function test_stacked_groups_wrap_into_columns_with_vertical_spacing()
  local W, groups = setup(4)
  W.container.flowOrientation = "horizontal"
  W.container.flowHorizontalSpacing = 99
  W.container.flowVerticalSpacing = 6
  GroupWrap.Wrap()
  assertAt(W, groups[2], 0, -186)
  assertAt(W, groups[5], 78, 0)
end

local function test_missing_spacing_counts_as_zero()
  local W, groups = setup(4)
  W.container.flowHorizontalSpacing = nil
  GroupWrap.Wrap()
  assertAt(W, groups[5], 0, -180)
end

local function test_origin_is_the_first_group_anchor()
  local W, groups = setup(4)
  groups[1]:ClearAllPoints()
  groups[1]:SetPoint("TOPLEFT", W.container, "TOPLEFT", 5, -3)
  GroupWrap.Wrap()
  assertAt(W, groups[1], 5, -3)
  assertAt(W, groups[5], 5, -183)
end

local function test_combat_defers_the_move_until_combat_ends()
  local W, groups = setup(4)
  W.inCombat = true
  GroupWrap.Wrap()
  assertAt(W, groups[5], 288, 0)
  Assert.equal(W.container:GetSize(), 0, "container not resized in combat")
  local events = eventFrame(W)
  Assert.equal(events:IsEventRegistered("PLAYER_REGEN_ENABLED"), true)

  W.inCombat = false
  W.fireEvent(events, "PLAYER_REGEN_ENABLED")
  assertAt(W, groups[5], 0, -180)
  Assert.equal(events:IsEventRegistered("PLAYER_REGEN_ENABLED"), false, "unregistered after retry")
end

local function test_regen_event_is_not_registered_out_of_combat()
  local W = setup(4)
  GroupWrap.Wrap()
  Assert.equal(eventFrame(W):IsEventRegistered("PLAYER_REGEN_ENABLED"), false)
end

local function test_blizzard_layout_of_the_raid_container_triggers_wrap()
  local W, groups = setup(4)
  W.callHooked(_G, "FlowContainer_DoLayout", W.container)
  assertAt(W, groups[5], 0, -180)
end

local function test_other_flow_containers_are_ignored()
  local W, groups = setup(4)
  W.callHooked(_G, "FlowContainer_DoLayout", {})
  assertAt(W, groups[5], 288, 0)
end

local function test_paused_flow_updates_are_ignored()
  local W, groups = setup(4)
  W.container.flowPauseUpdates = true
  W.callHooked(_G, "FlowContainer_DoLayout", W.container)
  assertAt(W, groups[5], 288, 0)
end

local function test_eight_per_line_leaves_blizzard_layout_untouched()
  local W, groups = setup(8)
  W.callHooked(_G, "FlowContainer_DoLayout", W.container)
  assertAt(W, groups[5], 288, 0)
  Assert.equal(W.container:GetSize(), 0, "container not resized")
end

local function test_odds_evens_puts_odd_groups_on_top_and_even_groups_below()
  local W, groups = setup(4, true)
  GroupWrap.Wrap()
  assertAt(W, groups[1], 0, 0)
  assertAt(W, groups[2], 0, -180)
  assertAt(W, groups[3], 72, 0)
  assertAt(W, groups[8], 216, -180)
  local width, height = W.container:GetSize()
  Assert.equal(width, 288)
  Assert.equal(height, 360)
end

local function test_odds_evens_at_three_per_row_wraps_the_odds_then_evens_order()
  local W, groups = setup(3, true)
  GroupWrap.Wrap()
  assertAt(W, groups[5], 144, 0)
  assertAt(W, groups[7], 0, -180)
  assertAt(W, groups[2], 72, -180)
  assertAt(W, groups[8], 72, -360)
end

-- A 20-player raid: Blizzard shows only groups 1-4 and their line breaks.
local function keepFirstFourGroups(W)
  for _ = 1, 8 do
    table.remove(W.container.flowFrames, 9)
  end
end

local function test_odds_evens_keeps_a_twenty_player_raid_on_one_row()
  local W, groups = setup(4, true)
  keepFirstFourGroups(W)
  GroupWrap.Wrap()
  assertAt(W, groups[1], 0, 0)
  assertAt(W, groups[3], 72, 0)
  assertAt(W, groups[2], 144, 0)
  assertAt(W, groups[4], 216, 0)
  local width, height = W.container:GetSize()
  Assert.equal(width, 288)
  Assert.equal(height, 180)
end

local function test_odds_evens_with_stacked_groups_puts_odds_in_the_first_columns()
  local W, groups = setup(2, true)
  W.container.flowOrientation = "horizontal"
  GroupWrap.Wrap()
  assertAt(W, groups[3], 0, -180)
  assertAt(W, groups[5], 72, 0)
  assertAt(W, groups[2], 144, 0)
end

local function test_odds_evens_keeps_each_group_size_with_its_group()
  local W, groups = setup(2, true)
  keepFirstFourGroups(W)
  groups[1]:SetSize(GROUP_WIDTH, 100)
  groups[3]:SetSize(GROUP_WIDTH, 50)
  groups[4]:SetSize(GROUP_WIDTH, 60)
  GroupWrap.Wrap()
  assertAt(W, groups[2], 0, -100)
  assertAt(W, groups[4], 72, -100)
  local _width, height = W.container:GetSize()
  Assert.equal(height, 280)
end

local function test_odds_evens_at_eight_per_line_leaves_blizzard_layout_untouched()
  local W, groups = setup(8, true)
  W.callHooked(_G, "FlowContainer_DoLayout", W.container)
  assertAt(W, groups[2], 72, 0)
  Assert.equal(W.container:GetSize(), 0, "container not resized")
end

-- The slider calls Wrap() directly when it moves to 8: groups go back to Blizzard's order.
local function test_odds_evens_at_eight_per_line_keeps_blizzard_order_when_wrapped_directly()
  local W, groups = setup(8, true)
  GroupWrap.Wrap()
  assertAt(W, groups[2], 72, 0)
  assertAt(W, groups[3], 144, 0)
end

local function test_hook_uses_hooksecurefunc_and_keeps_blizzard_function()
  local W = Wow.Install()
  local original = _G.FlowContainer_DoLayout
  GroupWrap.Install({ perLine = 4 })
  Assert.equal(_G.FlowContainer_DoLayout, original)
  Assert.equal(#W.secureHooks[_G].FlowContainer_DoLayout, 1)
end

local function test_wrap_never_writes_fields_on_blizzard_frames()
  local W, groups = setup(4, true) -- Odds / Evens on runs every layout step
  local containerBefore = W.snapshot(W.container)
  local groupBefore = W.snapshot(groups[5])
  W.callHooked(_G, "FlowContainer_DoLayout", W.container)
  W.inCombat = true
  GroupWrap.Wrap()
  Assert.equal(W.changedKeys(W.container, containerBefore), "")
  Assert.equal(W.changedKeys(groups[5], groupBefore), "")
  Assert.equal(#W.forbiddenCalls, 0, table.concat(W.forbiddenCalls, ","))
end

return function()
  test_wrap_moves_groups_into_rows_of_per_line()
  test_container_is_resized_to_the_wrapped_block()
  test_non_pet_frames_keep_blizzard_position()
  test_combined_groups_mode_is_left_alone()
  test_no_groups_does_nothing()
  test_side_by_side_rows_use_horizontal_spacing()
  test_stacked_groups_wrap_into_columns_with_vertical_spacing()
  test_missing_spacing_counts_as_zero()
  test_origin_is_the_first_group_anchor()
  test_combat_defers_the_move_until_combat_ends()
  test_regen_event_is_not_registered_out_of_combat()
  test_blizzard_layout_of_the_raid_container_triggers_wrap()
  test_other_flow_containers_are_ignored()
  test_paused_flow_updates_are_ignored()
  test_eight_per_line_leaves_blizzard_layout_untouched()
  test_odds_evens_puts_odd_groups_on_top_and_even_groups_below()
  test_odds_evens_at_three_per_row_wraps_the_odds_then_evens_order()
  test_odds_evens_keeps_a_twenty_player_raid_on_one_row()
  test_odds_evens_with_stacked_groups_puts_odds_in_the_first_columns()
  test_odds_evens_keeps_each_group_size_with_its_group()
  test_odds_evens_at_eight_per_line_leaves_blizzard_layout_untouched()
  test_odds_evens_at_eight_per_line_keeps_blizzard_order_when_wrapped_directly()
  test_hook_uses_hooksecurefunc_and_keeps_blizzard_function()
  test_wrap_never_writes_fields_on_blizzard_frames()
end
