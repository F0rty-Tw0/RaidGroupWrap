-- .luacheckrc for RaidGroupWrap (WoW addon, Retail + WoW: Forever)
-- Targets Lua 5.1 (WoW runtime)

std = "lua51"
max_line_length = false -- StyLua handles formatting; luacheck handles semantics
cache = true
jobs = 4

exclude_files = {
  ".luacheckrc",
  ".tools/",
}

ignore = {
  "212/self", -- unused 'self' in method definitions
  "211/addonName", -- unused first return from `local addonName, ns = ...`
  "212/addonName", -- same when treated as argument
  "331/ns", -- ns is set (mutated) then exported, not read directly
}

-- Globals the addon WRITES
globals = {
  -- SavedVariables (declared in .toc)
  "RaidGroupWrapDB",
}

-- Globals the addon READS (WoW API surface used by this addon)
read_globals = {
  -- Frames and hooks
  "CreateFrame",
  "UIParent",
  "hooksecurefunc",
  "Enum",

  -- Raid frames + Edit Mode (hooked or anchored to, never written)
  "CompactRaidFrameContainer",
  "EditModeSystemSettingsDialog",
  "MinimalSliderWithSteppersMixin",
  "CreateMinimalSliderFormatter",

  -- Misc
  "InCombatLockdown",
  "wipe",
}

-- Test files stub WoW globals freely
files["tests/**/*.lua"] = {
  globals = { "_G", "require" },
  ignore = {
    "111", -- setting undefined global (tests stub globals)
    "112", -- mutating undefined global
    "113", -- accessing undefined global
    "122", -- setting read-only field (tests stub read_globals)
    "142", -- setting undefined field of global
    "143", -- accessing undefined field of global
    "211", -- unused local variable
    "212", -- unused argument
    "421", -- shadowing local variable
    "431", -- shadowing upvalue
    "432", -- shadowing upvalue argument
  },
}
