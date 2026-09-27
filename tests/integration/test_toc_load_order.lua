-- The live client exposes a global `require` that throws for unknown modules,
-- so every file's `ns.X or require(...)` fallback must never be reached:
-- each dependency has to load earlier in the TOC.
local Wow = require("tests.helpers.wow")

local function tocFiles()
  local files = {}
  for line in io.lines("RaidGroupWrap.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" then
      -- Drop load conditions such as " [AllowLoadGameType mainline]".
      files[#files + 1] = string.gsub(line, "%s*%[.*$", "")
    end
  end
  return files
end

local function test_every_toc_file_loads_in_order_without_require()
  Wow.Install()
  local savedRequire = require
  _G.require = function(moduleName)
    error("Invalid import: No module with that name exists (" .. tostring(moduleName) .. ")")
  end

  local ns = {}
  local ok, err = pcall(function()
    for _, file in ipairs(tocFiles()) do
      local chunk = assert(loadfile(file))
      local loaded, loadErr = pcall(chunk, "RaidGroupWrap", ns)
      assert(loaded, file .. ": " .. tostring(loadErr))
    end
  end)

  _G.require = savedRequire
  assert(ok, tostring(err))
end

local function test_toc_lists_bootstrap_last()
  local files = tocFiles()
  assert(files[#files] == "Bootstrap.lua", tostring(files[#files]))
end

local ADDON_TEXTURE_PREFIX = "Interface\\AddOns\\RaidGroupWrap\\"

local function test_toc_icon_texture_points_at_shipped_tga()
  local iconPath
  for line in io.lines("RaidGroupWrap.toc") do
    iconPath = iconPath or string.match(line, "^## IconTexture: (.+)$")
  end
  assert(iconPath, "missing ## IconTexture")
  assert(string.sub(iconPath, 1, #ADDON_TEXTURE_PREFIX) == ADDON_TEXTURE_PREFIX, iconPath)
  local file = string.gsub(string.sub(iconPath, #ADDON_TEXTURE_PREFIX + 1), "\\", "/") .. ".tga"
  local handle = io.open(file, "rb")
  assert(handle, "icon file not found: " .. file)
  handle:close()
end

return function()
  test_every_toc_file_loads_in_order_without_require()
  test_toc_lists_bootstrap_last()
  test_toc_icon_texture_points_at_shipped_tga()
end
