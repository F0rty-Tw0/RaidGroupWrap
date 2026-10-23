local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local GroupWrap = require("RaidGroupWrap.Layout.GroupWrap")

local GROUP_WIDTH, GROUP_HEIGHT = 72, 180
local STACKED_WIDTH, STACKED_HEIGHT = 360, 60
local PET_WIDTH, PET_HEIGHT = 72, 24
-- Where Blizzard's flow puts the pet line after 8 side-by-side groups.
local BLIZZARD_PET_X, BLIZZARD_PET_Y = 576, 0

-- Separate Groups (Vertical): 8 groups side by side, IDs 1-8.
local function setup(perLine, flipFill, groupCount)
  local W = Wow.Install()
  local groups = {}
  for i = 1, groupCount or 8 do
    groups[i] = W.newGroup(GROUP_WIDTH, GROUP_HEIGHT, (i - 1) * GROUP_WIDTH, 0, i)
    W.container.flowFrames[#W.container.flowFrames + 1] = groups[i]
    W.container.flowFrames[#W.container.flowFrames + 1] = "linebreak"
  end
  local db = { perLine = perLine, flipFill = flipFill }
  GroupWrap.Install(db)
  return W, groups, db
end

-- Separate Groups (Horizontal): 8 groups stacked, each a row of members.
local function setupStacked(perLine, groupCount)
  local W = Wow.Install()
  W.container.flowOrientation = "horizontal"
  local groups = {}
  for i = 1, groupCount or 8 do
    groups[i] = W.newGroup(STACKED_WIDTH, STACKED_HEIGHT, 0, -(i - 1) * STACKED_HEIGHT, i)
    W.container.flowFrames[#W.container.flowFrames + 1] = groups[i]
    W.container.flowFrames[#W.container.flowFrames + 1] = "linebreak"
  end
  GroupWrap.Install({ perLine = perLine })
  return W, groups
end

-- A pet of raid member `rosterIndex`, who sits in `subgroup`, at Blizzard's spot.
local function addPet(W, unit, rosterIndex, subgroup)
  W.roster[rosterIndex] = subgroup
  local pet = W.newPet(unit, PET_WIDTH, PET_HEIGHT, BLIZZARD_PET_X, BLIZZARD_PET_Y)
  W.container.flowFrames[#W.container.flowFrames + 1] = pet
  return pet
end

local function assertAt(W, frame, x, y)
  local point, relativeTo, relativePoint, fx, fy = frame:GetPoint(1)
  Assert.equal(point, "TOPLEFT")
  Assert.equal(relativeTo, W.container)
  Assert.equal(relativePoint, "TOPLEFT")
  Assert.equal(fx, x, "x")
  Assert.equal(fy, y, "y")
  Assert.equal(frame:GetNumPoints(), 1, "old anchors cleared")
end

local function test_pet_sits_under_its_owner_group()
  local W, groups = setup(4)
  local pet = addPet(W, "raidpet21", 21, 5)
  GroupWrap.Wrap()
  assertAt(W, groups[5], 0, -180)
  assertAt(W, pet, 0, -360)
end

local function test_two_pets_of_one_group_stack_downward()
  local W = setup(4)
  local first = addPet(W, "raidpet21", 21, 5)
  local second = addPet(W, "raidpet22", 22, 5)
  GroupWrap.Wrap()
  assertAt(W, first, 0, -360)
  assertAt(W, second, 0, -384)
end

local function test_group_with_a_pet_makes_its_row_taller()
  local W, groups = setup(4)
  local pet = addPet(W, "raidpet6", 6, 2)
  GroupWrap.Wrap()
  assertAt(W, pet, 72, -180)
  assertAt(W, groups[5], 0, -204)
end

local function test_pet_under_first_group_keeps_the_origin()
  local W, groups = setup(4)
  local pet = addPet(W, "raidpet1", 1, 1)
  GroupWrap.Wrap()
  assertAt(W, groups[1], 0, 0)
  assertAt(W, pet, 0, -180)
  assertAt(W, groups[5], 0, -204)
end

local function test_pet_is_centred_under_a_bordered_group()
  local W, groups = setup(4)
  for _, group in ipairs(groups) do
    group:SetSize(80, GROUP_HEIGHT)
  end
  local pet = addPet(W, "raidpet21", 21, 5)
  GroupWrap.Wrap()
  assertAt(W, pet, 4, -360)
end

local function test_stacked_group_pets_form_a_row_under_it()
  local W, groups = setupStacked(4)
  local first = addPet(W, "raidpet6", 6, 2)
  local second = addPet(W, "raidpet7", 7, 2)
  GroupWrap.Wrap()
  assertAt(W, groups[2], 0, -60)
  assertAt(W, first, 0, -120)
  assertAt(W, second, 72, -120)
  assertAt(W, groups[3], 0, -144)
end

local function test_container_covers_owned_pets()
  local W = setup(4)
  addPet(W, "raidpet21", 21, 5)
  GroupWrap.Wrap()
  local width, height = W.container:GetSize()
  Assert.equal(width, 288)
  Assert.equal(height, 384)
end

-- The addon's own event frame: the only frame with an OnEvent script.
local function eventFrame(W)
  for _, frame in ipairs(W.frames) do
    if W.state(frame).scripts.OnEvent then
      return frame
    end
  end
end

-- Groups 7-8 not shown (e.g. Mythic), so their members' pets have no owner group.
local function test_orphan_pets_form_a_column_after_the_block()
  local W = setup(4, nil, 6)
  W.container.flowHorizontalSpacing = 10
  W.container.flowVerticalSpacing = 5
  local first = addPet(W, "raidpet39", 39, 7)
  local second = addPet(W, "raidpet40", 40, 7)
  GroupWrap.Wrap()
  assertAt(W, first, 328, 0)
  assertAt(W, second, 328, -29)
  local width, height = W.container:GetSize()
  Assert.equal(width, 400)
  Assert.equal(height, 370)
end

local function test_orphan_pets_form_a_row_below_stacked_groups()
  local W = setupStacked(4, 6)
  W.container.flowVerticalSpacing = 6
  W.container.flowHorizontalSpacing = 3
  local first = addPet(W, "raidpet39", 39, 7)
  local second = addPet(W, "raidpet40", 40, 7)
  GroupWrap.Wrap()
  assertAt(W, first, 0, -264)
  assertAt(W, second, 75, -264)
end

local function test_solo_pet_in_edit_mode_is_an_orphan()
  local W = setup(4)
  local pet = addPet(W, "pet", 0, nil)
  GroupWrap.Wrap()
  assertAt(W, pet, 288, 0)
end

local function test_pet_with_unknown_owner_is_an_orphan()
  local W = setup(4)
  local pet = addPet(W, "raidpet3", 3, nil)
  GroupWrap.Wrap()
  assertAt(W, pet, 288, 0)
end

-- The slider calls Wrap() directly when it moves to 8.
local function test_slider_to_eight_puts_pets_back_after_the_last_group()
  local W, _groups, db = setup(4)
  local pet = addPet(W, "raidpet21", 21, 5)
  GroupWrap.Wrap()
  assertAt(W, pet, 0, -360)
  db.perLine = 8
  GroupWrap.Wrap()
  assertAt(W, pet, 576, 0)
end

local function test_wrapping_twice_gives_the_same_pet_anchor()
  local W = setup(4)
  local pet = addPet(W, "raidpet21", 21, 5)
  GroupWrap.Wrap()
  GroupWrap.Wrap()
  assertAt(W, pet, 0, -360)
end

local function test_combat_defers_pet_moves_until_combat_ends()
  local W = setup(4)
  local pet = addPet(W, "raidpet21", 21, 5)
  W.inCombat = true
  GroupWrap.Wrap()
  assertAt(W, pet, BLIZZARD_PET_X, BLIZZARD_PET_Y)
  W.inCombat = false
  W.fireEvent(eventFrame(W), "PLAYER_REGEN_ENABLED")
  assertAt(W, pet, 0, -360)
end

local function test_odds_evens_keeps_pets_under_their_owner()
  local W, groups = setup(4, true)
  local pet = addPet(W, "raidpet21", 21, 5)
  GroupWrap.Wrap()
  assertAt(W, groups[5], 144, 0)
  assertAt(W, pet, 144, -180)
end

local function test_main_tank_frames_keep_their_anchor()
  local W = setup(4)
  local tank = W.newPet("raid1", 72, 36, 5, 7)
  local tankTarget = W.newPet("raid1target", 72, 36, 5, 43)
  local noUnit = W.newPet(nil, 72, 24, 9, 9)
  table.insert(W.container.flowFrames, 1, tank)
  table.insert(W.container.flowFrames, 2, tankTarget)
  table.insert(W.container.flowFrames, 3, noUnit)
  GroupWrap.Wrap()
  assertAt(W, tank, 5, 7)
  assertAt(W, tankTarget, 5, 43)
  assertAt(W, noUnit, 9, 9)
end

local function test_pet_placement_never_writes_fields()
  local W = setup(4, true)
  local pet = addPet(W, "raidpet21", 21, 5)
  local before = W.snapshot(pet)
  W.callHooked(_G, "FlowContainer_DoLayout", W.container)
  W.inCombat = true
  GroupWrap.Wrap()
  Assert.equal(W.changedKeys(pet, before), "")
  Assert.equal(#W.forbiddenCalls, 0, table.concat(W.forbiddenCalls, ","))
end

return function()
  test_orphan_pets_form_a_column_after_the_block()
  test_orphan_pets_form_a_row_below_stacked_groups()
  test_solo_pet_in_edit_mode_is_an_orphan()
  test_pet_with_unknown_owner_is_an_orphan()
  test_slider_to_eight_puts_pets_back_after_the_last_group()
  test_wrapping_twice_gives_the_same_pet_anchor()
  test_combat_defers_pet_moves_until_combat_ends()
  test_odds_evens_keeps_pets_under_their_owner()
  test_main_tank_frames_keep_their_anchor()
  test_pet_placement_never_writes_fields()
  test_pet_sits_under_its_owner_group()
  test_two_pets_of_one_group_stack_downward()
  test_group_with_a_pet_makes_its_row_taller()
  test_pet_under_first_group_keeps_the_origin()
  test_pet_is_centred_under_a_bordered_group()
  test_stacked_group_pets_form_a_row_under_it()
  test_container_covers_owned_pets()
end
