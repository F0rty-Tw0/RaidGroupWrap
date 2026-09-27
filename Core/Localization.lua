local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- English text is the key. A future Locale/<code>.lua fills `catalog` for
-- its client locale; call sites never change.
local Localization = { catalog = {} }

function Localization.Text(english)
  return Localization.catalog[english] or english
end

ns.Localization = Localization
return Localization
