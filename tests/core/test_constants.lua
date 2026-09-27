local Assert = require("tests.helpers.assert")
local Constants = require("RaidGroupWrap.Core.Constants")

local function test_version_matches_toc()
  local tocVersion
  for line in io.lines("RaidGroupWrap.toc") do
    tocVersion = tocVersion or string.match(line, "^## Version: (%S+)")
  end
  Assert.equal(Constants.VERSION, tocVersion)
end

local function test_max_groups_is_a_full_raid()
  Assert.equal(Constants.MAX_GROUPS, 8)
end

return function()
  test_version_matches_toc()
  test_max_groups_is_a_full_raid()
end
