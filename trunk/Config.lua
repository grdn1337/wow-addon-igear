-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iGear = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

--------------------------
-- The option table
--------------------------

function iGear:CreateDB()
	iGear.CreateDB = nil;
	
	return { profile = {
		AutoRepair = false,
		AutoRepairMode = 2,
		AutoRepairGuild = false,
		ConflictEquip = true,
		ConflictEnchant = true,
		ConflictGems = true,
		ConflictLevel = (_G.MAX_PLAYER_LEVEL - 10),
	}};
end

---------------------------------
-- The configuration table
---------------------------------

local function CreateConfig()
	return {
		type = "group",
		name = AddonName,
		order = 1,
		get = function(info)
			return iGear.db[info[#info]];
		end,
		set = function(info, value)
			iGear.db[info[#info]] = value;
		end,
		args = {
			EmptyLine1 = {
				type = "header",
				name = L["Auto Repair"],
				order = 10,
			},
			AutoRepair = {
				type = "toggle",
				name = _G.ENABLE,
				order = 20,
			},
			AutoRepairGuild = {
				type = "toggle",
				name = L["Try Guild Repair"],
				desc = L["If Action is set to Auto Repair, trys using Guild money for repairs. If it fails, falls back to your money!"],
				order = 30,
			},
			AutoRepairMode = {
				type = "select",
				name = L["Action"],
				order = 40,
				values = {
					[1] = L["Auto Repair"],
					[2] = L["Popup Dialog"]
				},
			},
			Spacer1 = {
				type = "description",
				name = " ",
				order = 49,
			},
			EmptyLine2 = {
				type = "header",
				name = L["Conflicts"],
				order = 50,
			},
			ConflictEquip = {
				type = "toggle",
				name = L["Missing Equip"],
				order = 60,
				set = function(info, value)
					iGear.db.ConflictEquip = value;
					iGear:UpdateBroker();
				end,
			},
			ConflictEnchant = {
				type = "toggle",
				name = L["Missing Enchants"],
				order = 70,
				set = function(info, value)
					iGear.db.ConflictEnchant = value;
					iGear:UpdateBroker();
				end,
			},
			ConflictGems = {
				type = "toggle",
				name = L["Missing Gems"],
				order = 80,
				set = function(info, value)
					iGear.db.ConflictGems = value;
					iGear:UpdateBroker();
				end,
			},
			Spacer2 = {
				type = "description",
				name = " ",
				order = 89,
			},
			ConflictLevel = {
				type = "range",
				name = L["Required level in order to check for equip conflicts"],
				order = 90,
				width = "full",
				min = 10,
				max = _G.MAX_PLAYER_LEVEL,
				step = 1,
				bigStep = 5,
				set = function(info, value)
					iGear.db.ConflictLevel = value;
					iGear:UpdateBroker();
				end,
			},
		},
	};
end

function iGear:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, CreateConfig);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["IGEAR"] = iGear.OpenOptions;
_G["SLASH_IGEAR1"] = "/igear";