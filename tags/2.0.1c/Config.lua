-----------------------------
-- Get the addon table
-----------------------------

local AddonName = select(1, ...);
local iGear = LibStub("AceAddon-3.0"):GetAddon(AddonName);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

---------------------------
-- Utility functions
---------------------------

-- a better strsplit function :)
local function strsplit(delimiter, text)
  local list = {}
  local pos = 1
  if strfind("", delimiter, 1) then -- this would result in endless loops
    --error("delimiter matches empty string!")
  end
  while 1 do
    local first, last = strfind(text, delimiter, pos)
    if first then -- found?
      tinsert(list, strsub(text, pos, first-1))
      pos = last+1
    else
      tinsert(list, strsub(text, pos))
      break
    end
  end
  return list
end

---------------------------------
-- The configuration table
---------------------------------

local function CreateConfig()
	CreateConfig = nil; -- we just need this function once, thus removing it from memory.

	local db = {
		type = "group",
		name = AddonName,
		order = 1,
		args = {
			
		},
	};
	
	return db;
end

function iGear:CreateDB()
	iGuild.CreateDB = nil;
	
	return { profile = {
		
	}};
end

function iGear:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, CreateConfig);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["IGEAR"] = iGear.OpenOptions;
_G["SLASH_IGEAR1"] = "/igear";