local Assert = require("tests.helpers.assert")
local Localization = require("RaidGroupWrap.Core.Localization")

local function test_english_text_is_its_own_key()
  Assert.equal(Localization.Text("Groups Per Row"), "Groups Per Row")
end

local function test_catalog_entry_replaces_english_text()
  Localization.catalog["Groups Per Row"] = "Gruppen pro Reihe"
  Assert.equal(Localization.Text("Groups Per Row"), "Gruppen pro Reihe")
  Localization.catalog["Groups Per Row"] = nil
end

return function()
  test_english_text_is_its_own_key()
  test_catalog_entry_replaces_english_text()
end
