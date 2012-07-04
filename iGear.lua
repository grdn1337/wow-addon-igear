-----------------------------------
-- Setting up scope and libs
-----------------------------------

local AddonName = select(1, ...);
iGear = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0", "AceBucket-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibQTip = LibStub("LibQTip-1.0");
local LibCrayon = LibStub("LibCrayon-3.0");

local _G = _G; -- upvalueing done here since I always will call _G.func()

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local Tooltip; -- our QTip object

local LowestDurability = 100; -- stores the lowest durability of an item
local RepairCosts = 0; -- calculated repaircosts
local BagLowestDurability = 100; -- stores the lowest durability of an item in bags
local BagRepairCosts = 0; -- calculated bag repaircosts
local BankLowestDurability = 100; -- stores the lowest durability of an item in bank
local BankRepairCosts = 0; -- calculated bank repaircosts

local isBanking = false; -- determines if we have opened the bank or not
local isRepairing = false; -- determines if we are currently repairing or not

local COLOR_GOLD = "|cfffed100%s|r";

-- This is iGears static info table which lets the addon know what to do with an itemslot.
-- In front of each index are two infos displayed. The first can be + (set by author) or - (set by iGear).
-- The second info is the data type in short, where i means int, s means string, b means bool. Simple!
--  + s  1: API internal slot name
--  - i  2: the API internal slot ID
--  + b  3: indicates whether a slot can be repaired or not
--  - i  4: the slot durability. Here the current item durability will be stored
--  - i  5: indicates how much gem slots are empty in the current slot
--  - i  6: stores the repair costs of the slot
--  + b  7: indicates whether a slot can be enchanted or not
--  - i  8: stores the enchant id of the enchant, where 0 means not enchanted
--  - b  9: indicates whether an item is equipped in the slot
--  - s 10: stores the itemlink of the weared item in this slot
--  - b 11: indicates whether the slot must be equipped or not
--  - b 12: indicates whether the Slot is used by the class or not
local EquipSlots = {
--   1           				2  3      4  5  6  7      8  9      10, 11		 12
	{"HeadSlot",					0, true,  0, 0, 0, true,  0, false, "", true,  true},	-- 1
	{"NeckSlot",					0, false, 0, 0, 0, false, 0, false, "", true,  true},	-- 2
	{"ShoulderSlot",			0, true,  0, 0, 0, true,  0, false, "", true,  true},	-- 3
	{"BackSlot",					0, false, 0, 0, 0, true,  0, false, "", true,  true},	-- 4
	{"ChestSlot",					0, true,  0, 0, 0, true,  0, false, "", true,  true},	-- 5
	--{"ShirtSlot" ... }
	--{"TabardSlot" ... }
	{"WristSlot",					0, true,  0, 0, 0, true,  0, false, "", true,  true},	-- 6
	{"HandsSlot",					0, true,  0, 0, 0, true,  0, false, "", true,  true},	-- 7
	{"WaistSlot",					0, true,  0, 0, 0, false, 0, false, "", true,  true},	-- 8
	{"LegsSlot",					0, true,  0, 0, 0, true,  0, false, "", true,  true},	-- 9
	{"FeetSlot",					0, true,  0, 0, 0, true,  0, false, "", true,  true},	-- 10
	{"Finger0Slot",				0, false, 0, 0, 0, false, 0, false, "", true,  true},	-- 11
	{"Finger1Slot",				0, false, 0, 0, 0, false, 0, false, "", true,  true},	-- 12
	{"Trinket0Slot",			0, false, 0, 0, 0, false, 0, false, "", true,  true},	-- 13
	{"Trinket1Slot",			0, false, 0, 0, 0, false, 0, false, "", true,  true},	-- 14
	{"MainHandSlot",			0, true,  0, 0, 0, true,  0, false, "", false, false},-- 15
	{"SecondaryHandSlot",	0, true,  0, 0, 0, true,  0, false, "", false, false},-- 16
	{"RangedSlot",				0, true,  0, 0, 0, true,  0, false, "", false, false}	-- 17
};

-- Yes, I prevent using key/value pairs in tables mostly, so every table index gets a name here:
local S_NAME = 1;
local S_ID = 2;
local S_CAN_REPAIR = 3;
local S_DURABILITY = 4;
local S_GEMS_EMPTY = 5;
local S_REPAIR_COST = 6;
local S_CAN_ENCHANT = 7;
local S_ENCHANT = 8;
local S_EQUIPPED = 9;
local S_LINK = 10;
local S_MUST_EQUIP = 11;
local S_USED = 12;

-----------------------------
-- Setting up the feed
-----------------------------

iGear.Feed = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = "",
	icon = "Interface\\Minimap\\Tracking\\Repair",
});

iGear.Feed.OnEnter = function(anchor)
	-- when there are no conflicts, we don't need the tooltip.
	if( iGear:GetNumConflicts() == 0 ) then
		return;
	end

	-- force other i-Series qtip's to hide, when this tip is to be shown
	for k, v in LibQTip:IterateTooltips() do
		if( type(k) == "string" and strsub(k, 1, 6) == "iSuite" ) then
			v:Release(k);
		end
	end
	
	Tooltip = LibQTip:Acquire("iSuite"..AddonName);
	Tooltip:SetAutoHideDelay(0.1, anchor);
	Tooltip:SmartAnchorTo(anchor);
	iGear:UpdateTooltip();
	Tooltip:Show();
end

iGear.Feed.OnClick = function(_, button)
	if( button == "RightButton" ) then
		iGear:OpenOptions();
	end
end

----------------------
-- OnInitialize
----------------------

function iGear:OnInitialize()
	-- on first run, we fetch the slot IDs by their slot name by some API calls. Why? Slot IDs could change, slot names doesn't ever change.
	for _, slot in ipairs(EquipSlots) do
		slot[S_ID] = _G.GetInventorySlotInfo(slot[S_NAME]);
	end
	
	self.bucket = self:RegisterBucketEvent(
		{
			"PLAYER_DEAD",
			"PLAYER_UNGHOST",
			"PLAYER_ENTERING_WORLD",
			"PLAYER_EQUIPMENT_CHANGED",
			"UPDATE_INVENTORY_DURABILITY"
		}, 0.5, "EventHandler");
	
	self:RegisterEvent("MERCHANT_SHOW", "MerchantInteraction", true);
	self:RegisterEvent("MERCHANT_CLOSED", "MerchantInteraction", false);
	
	self:RegisterEvent("BANKFRAME_OPENED", "BankInteraction", true);
	self:RegisterEvent("BANKFRAME_CLOSED", "BankInteraction", false);
end

----------------------
-- EventHandler
----------------------

function iGear:EventHandler()
	RepairCosts = 0;
	LowestDurability = 100; -- iGear displays the lowest durability on the feed.
	
	local isEquipped, repCosts, durability, enchant;
	
	self:CheckWeaponSlots();
	self:ScanBagsForRepCosts();
	if( isBanking ) then
		self:ScanBagsForRepCosts(true);
	end
	
	for _, s in ipairs(EquipSlots) do
		s[S_EQUIPPED] = false;
		s[S_REPAIR_COST] = 0;
		s[S_LINK] = "";
		s[S_DURABILITY] = 0;
		s[S_GEMS_EMPTY] = 0;
		s[S_ENCHANT] = 0;
		
		isEquipped, repCosts = self:GetItemEquippedAndCost(s[S_ID]);
				
		if( isEquipped ) then
			s[S_EQUIPPED] = true;
			s[S_REPAIR_COST] = repCosts;
			s[S_LINK] = _G.GetInventoryItemLink("player", s[S_ID]);
						
			-- check durability :)
			durability = self:GetItemDurability(s);
			if( durability ) then
				s[S_DURABILITY] = durability;
				
				if( durability < LowestDurability ) then
					LowestDurability = durability;
				end
				
				RepairCosts = RepairCosts + repCosts;
			end
			
			-- check misc stuff
			s[S_GEMS_EMPTY] = self:GetNumMissingGems(s);
			s[S_ENCHANT] = self:GetItemEnchant(s);
		end
	end
	
	self.Feed.text = self:FormatDurability(LowestDurability);
	
	local conflicts = self:GetNumConflicts();
	if( conflicts ~= 0 ) then
		self.Feed.text = ("|cffff0000%d!|r %s"):format(conflicts, self.Feed.text);
	end
	
	-- if tooltip is open, we refresh it
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

-----------------------------
-- MerchantInteraction
-----------------------------

function iGear:MerchantInteraction(isMerchant)
	-- we filter this event: only process if the merchant can repair!
	if( isMerchant and not _G.CanMerchantRepair() ) then
		return;
	end
	
	if( isMerchant ) then
		isRepairing = true;
	else
		isRepairing = false;
	end
	
	-- if tooltip is open, we refresh it
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

-------------------------
-- BankInteraction
-------------------------

function iGear:BankInteraction(isOpened)
	if( isOpened ) then
		self:RegisterEvent("BAG_UPDATE", "EventHandler");
		
		isBanking = true;
		self:ScanBagsForRepCosts(true);
	else
		self:UnregisterEvent("BAG_UPDATE");
		isBanking = false;
	end
	
	-- if tooltip is open, we refresh it
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

--------------------------
-- CheckWeaponSlots
--------------------------

-- Since MoP, weapon slots may vary and depend on the class you are playing.
-- Instead of getting rid off the RangedSlot, it is now used for Hunters etc as a main WeaponSlot
-- That means what? Yeah... we need to set up some vars by ourselves.
do
	local locClass, class = _G.UnitClass("player");
	
	-- Here I define some indexes for the EquipSlots table - all three Weapon Slots (Mainhand, Offhand, RangedWeapon)
	local MH = EquipSlots[15];
	local OH = EquipSlots[16];
	local RW = EquipSlots[17];
	
	-- Two Hand OR Main/Off Hand:	Warrior, Paladin, DeathKnight, Priest, Mage, Warlock, Druid, Shaman, Monk
	-- Main/Off Hand:							Rogue
	-- Just Ranged:								Hunter
	
	function iGear:CheckWeaponSlots()
		MH[S_MUST_EQUIP] = false;
		OH[S_MUST_EQUIP] = false;
		RW[S_MUST_EQUIP] = false;
		
		-----------------------
		-- these two are easy!
		if( class == "ROGUE" ) then
			MH[S_MUST_EQUIP] = true;
			OH[S_MUST_EQUIP] = true;
		elseif( class == "HUNTER" ) then
			RW[S_MUST_EQUIP] = true;
		-- end easiness :D
		-----------------------
		else
			local _, _, _, _, _, _, _, _, mh, _, _ = _G.GetItemInfo(MH[S_LINK]);
			
			if( mh == "INVTYPE_2HWEAPON" ) then
				MH[S_MUST_EQUIP] = true;
				
				if( class == "WARRIOR" and _G.GetSpecialization() == 2 ) then -- Furor warriors have TitanGrip
					OH[S_MUST_EQUIP] = true;
				end
			else
				MH[S_MUST_EQUIP] = true;
				OH[S_MUST_EQUIP] = true;
			end
			
			-- mh isn't set, that means the UI isn't fully loaded and values are wrong
			-- We give the UI half a second to load until we reload this! :)
			if( not mh ) then
				LibStub("AceTimer-3.0"):ScheduleTimer(iGear.EventHandler, 0.5, iGear); -- didn't want to add AceTimer to my addon object
			end
		end
	end
	
end

-----------------------
-- Conflicts
-----------------------

function iGear:GetSlotConflict(s, conflict)
	if( not s[S_MUST_EQUIP] ) then
		return false;
	end
	
	if( conflict == "equip" and s[S_MUST_EQUIP] and not s[S_EQUIPPED] ) then
		return true;
	end
	
	if( s[S_EQUIPPED] ) then
		if( conflict == "repair" and s[S_CAN_REPAIR] and s[S_REPAIR_COST] ~= 0 ) then
			return true;
		end
		
		if( conflict == "enchant" and s[S_CAN_ENCHANT] and s[S_ENCHANT] == 0 ) then
			return true;
		end
		
		if( conflict == "gems" and s[S_GEMS_EMPTY] > 0 ) then
			return true;
		end
	end
	
	return false;
end

function iGear:GetSlotConflictText(s)
	local t = {};
	
	if( self:GetSlotConflict(s, "equip") ) then
		table.insert(t, ("|cffff0000%s|r"):format("Eq"));
	end
	
	if( self:GetSlotConflict(s, "enchant") ) then
		table.insert(t, ("|cff00ffff%s|r"):format("En"));
	end
	
	if( self:GetSlotConflict(s, "gems") ) then
		table.insert(t, ("|cffff00ff%d%s|r"):format(s[S_GEMS_EMPTY], "Ge"));
	end
	
	return (#t > 0 and " " or "")..table.concat(t, ", ");
end

function iGear:GetNumSlotConflicts(s, conflict, no)
	local conflicts = 0;
	
	if( not conflict ) then
		conflict = "all";
		no = 1;
	end
	
	if( (conflict == "equip" and not no) or ( conflict ~= "equip" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(s, "equip") and 1 or 0);
	end
	if( (conflict == "repair" and not no) or ( conflict ~= "repair" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(s, "repair") and 1 or 0);
	end
	if( (conflict == "enchant" and not no) or (conflict ~= "enchant" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(s, "enchant") and 1 or 0);
	end
	if( (conflict == "gems" and not no) or (conflict ~= "gems" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(s, "gems") and 1 or 0);
	end
	
	return conflicts;
end

function iGear:GetNumConflicts(conflict, no)
	local conflicts = 0;
	
	for _, s in ipairs(EquipSlots) do
		conflicts = conflicts + self:GetNumSlotConflicts(s, conflict, no);
	end
	
	return conflicts;
end

--------------------------
-- Get Item Infos
--------------------------

-- This frame is a fake GameTooltip object which allows us to scan data from it
_G.CreateFrame("GameTooltip", "iGearScanTip", _G.UIParent, "GameTooltipTemplate");

function iGear:GetNumMissingGems(s)
	local stats = _G.GetItemStats(s[S_LINK]);
	if( not stats or type(stats) ~= 'table' ) then
		return 0;
	end
	
	local iter = 1;
	local missing = 0;
	local gem;
	
	for k, v in pairs(stats) do
		if( strsub(k, 0, 12) == 'EMPTY_SOCKET' ) then
			gem = _G.GetItemGem(s[S_LINK], iter);
			
			if( not gem ) then
				missing = missing + v;
			else
				gem = nil;
			end
			
			iter = iter + 1;
		end
	end
	
	return missing;
end

function iGear:GetItemEquippedAndCost(slotNum)
	_G.iGearScanTip:ClearLines();
	
	local equipped, _, cost = _G.iGearScanTip:SetInventoryItem("player", slotNum);
	_G.iGearScanTip:Hide();
	
	return equipped, cost;
end

function iGear:GetItemDurability(s)
	-- no durability if item has no durability on it
	if( not s[S_CAN_REPAIR] ) then
		return;
	end
	
	-- if the item is broken, durability automatically is 0!
	if( _G.GetInventoryItemBroken("player", s[S_ID]) ) then
		return 0;
	end
	local current, maximum = _G.GetInventoryItemDurability(s[S_ID]);
	
	if( not current or not maximum ) then
		return;
	end
	-- let's do some math to get the percent item durability.
	local durability = 100 * current / maximum;
	
	if( durability - abs(durability) >= 0.5 ) then
		durability = ceil(durability);
	else
		durability = floor(durability);
	end
	
	return durability;
end

function iGear:GetItemEnchant(s)
	local _, _, color, enchant, name =
		string.find(s[S_LINK],"|c%x%x(%x*)|Hitem:%d+:(%d+):%d+:%d+:%d+:%d+:%-?%d+:%-?%d+:%d+:%d+|h%[([^%]]*)%]");
	
	return tonumber(enchant);
end

function iGear:ScanBagsForRepCosts(scanBank)
	local _, current, maximum, repair;
	
	local bags;
	if( not scanBank ) then
		BagRepairCosts = 0;
		BagLowestDurability = 100;
		bags = {0, 1, 2, 3, 4};
	else
		BankRepairCosts = 0;
		BankLowestDurability = 100;
		bags = {-1, 5, 6, 7, 8, 9, 10, 11};
	end
	
	local repairValue, durabilityValue = 0, 100;
	
	--for bag = 0, 4 do
	for i, bag in ipairs(bags) do
		for slot = 1, _G.GetContainerNumSlots(bag) do
			current, maximum = _G.GetContainerItemDurability(bag, slot);
			_, repair = _G.iGearScanTip:SetBagItem(bag, slot);
			
			if( current and maximum and repair ) then				
				repairValue = repairValue + repair; -- add to bag repair costs
				
				current = 100 * current / maximum;
				
				if( current - abs(current) >= 0.5 ) then
					current = ceil(current);
				else
					current = floor(current);
				end
				
				if( current < durabilityValue ) then
					durabilityValue = current;
				end
			end
		end
	end
	
	if( not scanBank ) then
		BagRepairCosts = repairValue;
		BagLowestDurability = durabilityValue;
	else
		BankRepairCosts = repairValue;
		BankLowestDurability = durabilityValue;
	end
end

-----------------------
-- UpdateTooltip
-----------------------

function iGear:FormatDurability(durability)
	return ("|cff%s%d%%|r"):format(LibCrayon:GetThresholdHexColor(durability, 100), durability);
end

function iGear:FormatMoney(value, standing)
	local discount = self:GetRepairDiscount(standing);
	
	value = value * discount;
	
	return _G.GetMoneyString(value);
end

function iGear:GetRepairDiscount(standing, returnStanding)
	if( not standing and isRepairing ) then
		standing = _G.UnitReaction("npc", "player");
		
		if( returnStanding ) then
			return standing;
		end
	end
	
	local discount = 1; -- 100 % cost
	
	if( standing and standing > 4 ) then
		discount = 1 - (standing - 4) * 0.05;
	end
	
	return discount;
end

local function LineEnter(anchor, slotNum)
	--_G.GameTooltip_SetDefaultAnchor(_G.GameTooltip, _G.UIParent);
	_G.GameTooltip:SetOwner(anchor, "ANCHOR_BOTTOMRIGHT", 10, anchor:GetHeight()+2);
	_G.GameTooltip:SetInventoryItem("player", slotNum);
	_G.GameTooltip:Show();
end

local function LineLeave()
	_G.GameTooltip:ClearLines();
	_G.GameTooltip:Hide();
end

function iGear:UpdateTooltip()
	Tooltip:Clear();
	
	local line;
	local text_slot, text_conflict, text_durability, text_costs;
	
	local conflicts_rep   = self:GetNumConflicts("repair");
	local conflicts_norep = self:GetNumConflicts("repair", 1);
	Tooltip:SetColumnLayout(4, "LEFT", "LEFT", "LEFT", "RIGHT");
	
	line = Tooltip:AddHeader("");
	Tooltip:SetCell(line, 1, "Equip", nil, "LEFT", 4);
	
	for _, s in ipairs(EquipSlots) do
		if( s[S_MUST_EQUIP] and self:GetNumSlotConflicts(s) > 0 ) then
			
			text_slot = (COLOR_GOLD):format(L[s[S_NAME]]);
			
			if( conflicts_norep ) then
				text_conflict = self:GetSlotConflictText(s);
			else
				text_conflict = "";
			end
			
			if( self:GetSlotConflict(s, "repair") ) then
				text_durability = self:FormatDurability(s[S_DURABILITY]);
				text_costs = self:FormatMoney(s[S_REPAIR_COST]);
			else
				text_durability = "";
				text_costs = "";
			end
			
			line = Tooltip:AddLine(text_slot, text_conflict, text_durability, text_costs);
			
			if( conflicts_rep > 0 and conflicts_norep == 0 ) then
				Tooltip:SetCell(line, 1, text_slot, nil, "LEFT", 2);
			elseif( conflicts_rep == 0 and conflicts_norep > 0 ) then
				Tooltip:SetCell(line, 2, text_conflict, nil, "LEFT", 3);
			end
			
			Tooltip:SetLineScript(line, "OnEnter", LineEnter, s[S_ID]);
			Tooltip:SetLineScript(line, "OnLeave", LineLeave);
		end
	end
	Tooltip:AddLine(" ");
	
	if( (BagRepairCosts + BankRepairCosts) > 0 ) then
		line = Tooltip:AddHeader("");
		Tooltip:SetCell(line, 1, "Inventory", nil, "LEFT", 4);
		
		if( BagRepairCosts > 0 ) then
			text_slot = (COLOR_GOLD):format("In Bags");
			text_durability = self:FormatDurability(BagLowestDurability);
			text_costs = self:FormatMoney(BagRepairCosts);
			
			line = Tooltip:AddLine(text_slot, "", text_durability, text_costs);
			if( conflicts_norep == 0 ) then
				Tooltip:SetCell(line, 1, text_slot, nil, "LEFT", 2);
			end
		end
		
		if( BankRepairCosts > 0 ) then
			text_slot = (COLOR_GOLD):format("At Bank");
			text_durability = self:FormatDurability(BankLowestDurability);
			text_costs = self:FormatMoney(BankRepairCosts);
			
			line = Tooltip:AddLine(text_slot, "", text_durability, text_costs);
			if( conflicts_norep == 0 ) then
				Tooltip:SetCell(line, 1, text_slot, nil, "LEFT", 2);
			end
		end
		
		Tooltip:AddLine(" ");
	end
	
	-- total repair costs
	if( conflicts_rep > 0 ) then
		line = Tooltip:AddHeader("");
		Tooltip:SetCell(line, 1, "Total Cost", nil, "LEFT", 4);
		
		local c;
		
		for i = 8, 4, -1 do
			line = Tooltip:AddLine("");
			c = _G.FACTION_BAR_COLORS[i];
			
			Tooltip:SetCell(line, 1, ("|cff%02x%02x%02x%s|r"):format(c.r *255, c.g *255, c.b *255, _G["FACTION_STANDING_LABEL"..i]), nil, "LEFT", 3);
			Tooltip:SetCell(line, 4, self:FormatMoney( (RepairCosts + BagRepairCosts), i), nil, "RIGHT");
			
			if( self:GetRepairDiscount(nil, true) == i ) then
				Tooltip:SetLineColor(line, c.r, c.g, c.b, 0.4);
			end
		end
	end
end