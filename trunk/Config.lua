-----------------------------
-- Get the addon table
-----------------------------

local AddonName = select(1, ...);
local iGear = LibStub("AceAddon-3.0"):GetAddon(AddonName);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

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
			EmptyLine1 = {
				type = "header",
				name = "Auto Repair",
				order = 10,
			},
			AutoRepair = {
				type = "toggle",
				name = "Enable",
				order = 20,
				get = function()
					return iGear.db.AutoRepair;
				end,
				set = function(info, value)
					iGear.db.AutoRepair = value;
				end,
			},
			AutoRepairGuild = {
				type = "toggle",
				name = "Try Guild Repair",
				desc = "If Action is set to Auto Repair, trys using Guild money for repairs. If it fails, falls back to your money!",
				order = 30,
				get = function()
					return iGear.db.AutoRepairGuild;
				end,
				set = function(info, value)
					iGear.db.AutoRepairGuild = value;
				end,
			},
			AutoRepairMode = {
				type = "select",
				name = "Action",
				order = 40,
				get = function()
					return iGear.db.AutoRepairMode;
				end,
				set = function(info, value)
					iGear.db.AutoRepairMode = value;
				end,
				values = {
					[1] = "Auto Repair",
					[2] = "Popup Dialog"
				},
			},
		},
	};
	
	return db;
end

function iGear:CreateDB()
	iGear.CreateDB = nil;
	
	return { profile = {
		AutoRepair = false,
		AutoRepairMode = 2,
		AutoRepairGuild = false,
	}};
end

function iGear:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, CreateConfig);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["IGEAR"] = iGear.OpenOptions;
_G["SLASH_IGEAR1"] = "/igear";