local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = {
  VERSION = "v1.0.0",

  -- Raid groups in a full raid. Also the slider maximum: 8 per line is
  -- Blizzard's own look, so at 8 the addon idles.
  MAX_GROUPS = 8,
}

ns.Constants = Constants
return Constants
