local Assert = require("tests.helpers.assert")
local GroupGrid = require("RaidGroupWrap.Layout.GroupGrid")

local SIDE_BY_SIDE = true
local STACKED = false

local function sizes(count, width, height)
  local list = {}
  for i = 1, count do
    list[i] = { width = width, height = height }
  end
  return list
end

local function assertAt(points, index, x, y)
  Assert.equal(points[index].x, x, "x of group " .. index)
  Assert.equal(points[index].y, y, "y of group " .. index)
end

local function test_per_line_at_or_above_count_is_one_blizzard_line()
  local points, right, bottom = GroupGrid.Layout(sizes(5, 72, 180), 8, SIDE_BY_SIDE, 0, 0, 0)
  for i = 1, 5 do
    assertAt(points, i, (i - 1) * 72, 0)
  end
  Assert.equal(right, 360)
  Assert.equal(bottom, -180)
end

local function test_eight_groups_wrap_after_four()
  local points, right, bottom = GroupGrid.Layout(sizes(8, 72, 180), 4, SIDE_BY_SIDE, 0, 0, 0)
  assertAt(points, 4, 216, 0)
  assertAt(points, 5, 0, -180)
  assertAt(points, 8, 216, -180)
  Assert.equal(right, 288)
  Assert.equal(bottom, -360)
end

local function test_row_height_is_the_tallest_group()
  local list = {
    { width = 72, height = 100 },
    { width = 72, height = 180 },
    { width = 72, height = 50 },
    { width = 72, height = 120 },
  }
  local points, _right, bottom = GroupGrid.Layout(list, 2, SIDE_BY_SIDE, 0, 0, 0)
  assertAt(points, 3, 0, -180)
  assertAt(points, 4, 72, -180)
  Assert.equal(bottom, -300)
end

local function test_stacked_groups_wrap_into_a_new_column_to_the_right()
  local list = {
    { width = 72, height = 180 },
    { width = 90, height = 180 },
    { width = 72, height = 180 },
  }
  local points, right, bottom = GroupGrid.Layout(list, 2, STACKED, 0, 0, 0)
  assertAt(points, 1, 0, 0)
  assertAt(points, 2, 0, -180)
  assertAt(points, 3, 90, 0)
  Assert.equal(right, 162)
  Assert.equal(bottom, -360)
end

local function test_gap_separates_groups_and_lines()
  local points, right, bottom = GroupGrid.Layout(sizes(3, 72, 180), 2, SIDE_BY_SIDE, 0, 0, 10)
  assertAt(points, 2, 82, 0)
  assertAt(points, 3, 0, -190)
  Assert.equal(right, 154)
  Assert.equal(bottom, -370)
end

local function test_stacked_gap_separates_columns()
  local points = GroupGrid.Layout(sizes(3, 72, 180), 2, STACKED, 0, 0, 6)
  assertAt(points, 2, 0, -186)
  assertAt(points, 3, 78, 0)
end

local function test_one_per_line_puts_every_group_on_its_own_row()
  local points, right, bottom = GroupGrid.Layout(sizes(3, 72, 180), 1, SIDE_BY_SIDE, 0, 0, 0)
  assertAt(points, 1, 0, 0)
  assertAt(points, 2, 0, -180)
  assertAt(points, 3, 0, -360)
  Assert.equal(right, 72)
  Assert.equal(bottom, -540)
end

local function test_origin_offsets_every_group()
  local points, right, bottom = GroupGrid.Layout(sizes(3, 72, 180), 2, SIDE_BY_SIDE, 5, -3, 0)
  assertAt(points, 1, 5, -3)
  assertAt(points, 3, 5, -183)
  Assert.equal(right, 149)
  Assert.equal(bottom, -363)
end

local function test_output_buffer_is_reused()
  local out = {}
  local points = GroupGrid.Layout(sizes(2, 72, 180), 8, SIDE_BY_SIDE, 0, 0, 0, out)
  local first = out[1]
  GroupGrid.Layout(sizes(2, 72, 180), 1, SIDE_BY_SIDE, 0, 0, 0, out)
  Assert.equal(points, out)
  Assert.equal(out[1], first, "point table reused")
  assertAt(out, 2, 0, -180)
end

return function()
  test_per_line_at_or_above_count_is_one_blizzard_line()
  test_eight_groups_wrap_after_four()
  test_row_height_is_the_tallest_group()
  test_stacked_groups_wrap_into_a_new_column_to_the_right()
  test_gap_separates_groups_and_lines()
  test_stacked_gap_separates_columns()
  test_one_per_line_puts_every_group_on_its_own_row()
  test_origin_offsets_every_group()
  test_output_buffer_is_reused()
end
