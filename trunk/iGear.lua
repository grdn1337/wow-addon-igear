-----------------------------------
-- Setting up scope and libs
-----------------------------------

local AddonName, iGear = ...;
LibStub("AceEvent-3.0"):Embed(iGear);
LibStub("AceBucket-3.0"):Embed(iGear);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibCrayon = LibStub("LibCrayon-3.0");

local _G = _G;
local format = _G.string.format;

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, iGear);


-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local Bucket;

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
	{"HeadSlot",					0, true,  0, 0, 0, false, 0, false, "", true,  true},	-- 1
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
	-- the ranged slot got completely removed
	--{"RangedSlot",				0, true,  0, 0, 0, true,  0, false, "", false, false}	-- 17
};

do
	local mt = {
		__index = function(t, k)
			if(     k == "name" ) then return t[1]
			elseif( k == "id" ) then return t[2]
			elseif( k == "canRepair" ) then return t[3]
			elseif( k == "durability" ) then return t[4]
			elseif( k == "gemsEmpty" ) then return t[5]
			elseif( k == "repair" ) then return t[6]
			elseif( k == "canEnchant" ) then return t[7]
			elseif( k == "enchant" ) then return t[8]
			elseif( k == "equipped" ) then return t[9]
			elseif( k == "link" ) then return t[10]
			elseif( k == "mustEquip" ) then return t[11]
			elseif( k == "used" ) then return t[12]
			end
		end,
		__newindex = function(t, k, v)
			local slot;
			
			if( k == "id" ) then slot = 2
			-- 3 is set by the author
			elseif( k == "durability" ) then slot = 4
			elseif( k == "gemsEmpty" ) then slot = 5
			elseif( k == "repair" ) then slot = 6
			-- 7 is set by the author
			elseif( k == "enchant" ) then slot = 8
			elseif( k == "equipped" ) then slot = 9
			elseif( k == "link" ) then slot = 10
			elseif( k == "mustEquip" ) then slot = 11
			-- 12: what the hell...?!
			end
			
			if( slot ) then
				rawset(t, slot, v);
			end
		end
	};
	
	for _, v in ipairs(EquipSlots) do
		setmetatable(v, mt);
	end
end

-----------------------------
-- Setting up the LDB
-----------------------------

iGear.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = "",
	icon = "Interface\\Minimap\\Tracking\\Repair",
});

iGear.ldb.OnClick = function(_, button)
	if( not _G.IsModifierKeyDown() and button == "RightButton" ) then
		iGear:OpenOptions();
	end
end

iGear.ldb.OnEnter = function(anchor)
	-- when there are no conflicts, we don't need the tooltip.
	if( iGear:IsTooltip("Main") or iGear:GetNumConflicts() == 0 ) then
		return;
	end

	iGear:HideAllTooltips();
	
	local tip = iGear:GetTooltip("Main", "UpdateTooltip");
	tip:SetAutoHideDelay(0.25, anchor);
	tip:SmartAnchorTo(anchor);
	tip:Show();
end

iGear.ldb.OnLeave = function() end

----------------------
-- OnInitialize
----------------------

function iGear:Boot()
	self.db = LibStub("AceDB-3.0"):New("iGearDB", self:CreateDB(), "Default").profile;
	
	-- on first run, we fetch the slot IDs by their slot name by some API calls. Why?
	-- Slot IDs could change, slot names doesn't ever change.
	for _, slot in ipairs(EquipSlots) do
		slot.id = _G.GetInventorySlotInfo(slot.name);
	end
	
	Bucket = self:RegisterBucketEvent(
		{
			"PLAYER_DEAD",
			"PLAYER_UNGHOST",
			"PLAYER_EQUIPMENT_CHANGED",
			"UPDATE_INVENTORY_DURABILITY",
			"PLAYER_SPECIALIZATION_CHANGED"
		}, 0.5, "EventHandler"
	);
	
	self:RegisterEvent("MERCHANT_SHOW", "MerchantInteraction", true);
	self:RegisterEvent("MERCHANT_CLOSED", "MerchantInteraction", false);
	self:RegisterEvent("BANKFRAME_OPENED", "BankInteraction", true);
	self:RegisterEvent("BANKFRAME_CLOSED", "BankInteraction", false);
	
	self:EventHandler();
	
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
end
iGear:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");

----------------------
-- UpdateBroker
----------------------

function iGear:UpdateBroker()
	self.ldb.text = self:FormatDurability(LowestDurability);
	
	local conflicts = self:GetNumConflicts("repair", true);
	if( conflicts > 0 ) then
		self.ldb.text = ("|cffff0000%d!|r %s"):format(conflicts, self.ldb.text);
	end
end

----------------------
-- EventHandler
----------------------

function iGear:EventHandler()
	RepairCosts = 0;
	LowestDurability = 100; -- iGear displays the lowest durability on the ldb.
	
	local isEquipped, repCosts, durability, enchant;
	
	self:CheckWeaponSlots();
	self:ScanBagsForRepCosts();
	if( isBanking ) then
		self:ScanBagsForRepCosts(true);
	end
	
	for _, slot in ipairs(EquipSlots) do
		slot.equipped = false;
		slot.repair = 0;
		slot.link = "";
		slot.durability = 0;
		slot.gemsEmpty = 0;
		slot.enchant = 0;
		
		isEquipped, repCosts = self:GetItemEquippedAndCost(slot.id);
				
		if( isEquipped ) then
			slot.equipped = true;
			slot.repair = repCosts;
			slot.link = _G.GetInventoryItemLink("player", slot.id);
						
			-- check durability :)
			durability = self:GetItemDurability(slot);
			if( durability ) then
				slot.durability = durability;
				
				if( durability < LowestDurability ) then
					LowestDurability = durability;
				end
				
				RepairCosts = RepairCosts + repCosts;
			end
			
			-- check misc stuff
			slot.enchant = self:GetItemEnchant(slot);
			slot.gemsEmpty = self:GetNumMissingGems(slot);
		end
	end
	
	self:UpdateBroker();
	self:CheckTooltips("Main");
end

-----------------------------
-- MerchantInteraction
-----------------------------

function iGear:MerchantInteraction(isMerchant)
	-- we filter this event: only process if the merchant can repair!
	if( isMerchant and not _G.CanMerchantRepair() ) then
		return;
	end
	
	isRepairing = isMerchant;
	if( isRepairing ) then
		self:MerchantAutoRepair();
	else
		if( _G.StaticPopup_FindVisible("IGEAR_AUTOREPAIR") ) then
			_G.StaticPopup_Hide("IGEAR_AUTOREPAIR");
		end
	end
	
	self:CheckTooltips("Main");
end

function iGear:MerchantAutoRepair()
	if( not isRepairing or not self.db.AutoRepair or (RepairCosts + BagRepairCosts) == 0 ) then
		return;
	end
	
	if( self.db.AutoRepairMode == 1 ) then
		if( self.db.AutoRepairGuild ) then
			self:MerchantDoGuildRepair(true);
		else
			self:MerchantDoRepair();
		end
	else
		_G.StaticPopupDialogs["IGEAR_AUTOREPAIR"].text =
			("%s\n%s: %s"):format(L["Who is paying the bill?"], L["Total Cost"], self:FormatMoney(RepairCosts + BagRepairCosts));
		_G.StaticPopup_Show("IGEAR_AUTOREPAIR");
	end
end

function iGear:MerchantDoRepair()
	_G.RepairAllItems();
end

function iGear:MerchantCanGuildRepair()
	return (_G.CanGuildBankRepair() and _G.GetGuildBankWithdrawMoney() > (RepairCosts + BagRepairCosts) );
end

function iGear:MerchantDoGuildRepair()
	if( self:MerchantCanGuildRepair() ) then
		_G.RepairAllItems(1);
		return;
	end
	
	self:MerchantDoRepair();
end

-------------------------
-- BankInteraction
-------------------------

function iGear:BankInteraction(isOpened)
	isBanking = isOpened;
	
	if( isBanking ) then
		self:RegisterEvent("BAG_UPDATE", "EventHandler");
		self:ScanBagsForRepCosts(true);
	else
		self:UnregisterEvent("BAG_UPDATE");
	end
	
	self:CheckTooltips("Main");
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
	
	-- Two Hand OR Main/Off Hand:	Warrior, Paladin, DeathKnight, Priest, Mage, Warlock, Druid, Shaman, Monk
	-- Just Mainhand:							Hunter
	-- Main/Off Hand:							Rogue
	
	function iGear:CheckWeaponSlots()
		MH.mustEquip = false;
		OH.mustEquip = false;
		
		-----------------------
		-- these two are easy!
		if( class == "ROGUE" ) then
			MH.mustEquip = true;
			OH.mustEquip = true;
		elseif( class == "HUNTER" ) then
			MH.mustEquip = true;
		--end easiness :D
		-----------------------
		else
			local _, _, _, _, _, _, _, _, mh, _, _ = _G.GetItemInfo(MH.link);
			
			if( mh == "INVTYPE_2HWEAPON" ) then
				MH.mustEquip = true;
				
				if( class == "WARRIOR" and _G.GetSpecialization() == 2 ) then -- Furor warriors have TitanGrip
					OH.mustEquip = true;
				end
			else
				MH.mustEquip = true;
				OH.mustEquip = true;
			end
			
			-- mh isn't set, that means the UI isn't fully loaded and values are wrong
			-- We give the UI half a second to load until we reload this! :)
			if( not mh ) then
				LibStub("AceTimer-3.0"):ScheduleTimer(self.EventHandler, 0.5, self); -- didn't want to add AceTimer to my addon object
			end
		end
	end
	
end

-----------------------
-- Conflicts
-----------------------

function iGear:GetSlotConflict(slot, conflict)
	if( not slot.mustEquip ) then
		return false;
	end
	local reqLevel = (_G.UnitLevel("player") >= self.db.ConflictLevel);
	
	if( conflict == "equip" and slot.mustEquip and not slot.equipped and reqLevel and self.db.ConflictEquip ) then
		return true;
	end
	
	if( slot.equipped ) then
		if( conflict == "repair" and slot.canRepair and slot.repair ~= 0 ) then
			return true;
		end
		
		if( conflict == "enchant" and slot.canEnchant and slot.enchant == 0 and reqLevel and self.db.ConflictEnchant ) then
			return true;
		end
		
		if( conflict == "gems" and slot.gemsEmpty > 0 and reqLevel and self.db.ConflictGems ) then
			return true;
		end
	end
	
	return false;
end

function iGear:GetNumSlotConflicts(slot, conflict, no)
	local conflicts = 0;
	
	if( not conflict ) then
		conflict = "all";
		no = 1;
	end
	
	if( (conflict == "equip" and not no) or ( conflict ~= "equip" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(slot, "equip") and 1 or 0);
	end
	if( (conflict == "repair" and not no) or ( conflict ~= "repair" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(slot, "repair") and 1 or 0);
	end
	if( (conflict == "enchant" and not no) or (conflict ~= "enchant" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(slot, "enchant") and 1 or 0);
	end
	if( (conflict == "gems" and not no) or (conflict ~= "gems" and no) ) then
		conflicts = conflicts + (self:GetSlotConflict(slot, "gems") and 1 or 0);
	end
	
	return conflicts;
end

function iGear:GetNumConflicts(conflict, no)
	local conflicts = 0;
	
	for _, slot in ipairs(EquipSlots) do
		conflicts = conflicts + self:GetNumSlotConflicts(slot, conflict, no);
	end
	
	return conflicts;
end

function iGear:GetSlotConflictText(slot)
	local t = {};
	
	if( self:GetSlotConflict(slot, "equip") ) then
		table.insert(t, ("|cffff0000%s|r"):format(L["Eq"]));
	end
	
	if( self:GetSlotConflict(slot, "enchant") ) then
		table.insert(t, ("|cff00ffff%s|r"):format(L["En"]));
	end
	
	if( self:GetSlotConflict(slot, "gems") ) then
		table.insert(t, ("|cffff00ff%d%s|r"):format(slot.gemsEmpty, L["Ge"]));
	end
	
	return (#t > 0 and " " or "")..table.concat(t, ", ");
end

--------------------------
-- Get Item Infos
--------------------------

-- This frame is a fake GameTooltip object which allows us to scan data from it
_G.CreateFrame("GameTooltip", "iGearScanTip", _G.UIParent, "GameTooltipTemplate");

function iGear:GetNumMissingGems(slot)
	local stats = _G.GetItemStats(slot.link);
	if( type(stats) ~= "table" ) then
		return 0;
	end
	
	local iter, missing = 1, 0;
	local gem;
	
	for k, v in pairs(stats) do
		if( strsub(k, 0, 12) == 'EMPTY_SOCKET' ) then
			gem = _G.GetItemGem(slot.link, iter);
			
			if( not gem ) then
				missing = missing + v;
			end
			
			gem = nil;
			iter = iter + 1;
		end
	end
	
	return missing;
end

function iGear:GetItemEquippedAndCost(slotID)
	_G.iGearScanTip:ClearLines();
	
	local equipped, _, cost = _G.iGearScanTip:SetInventoryItem("player", slotID);
	_G.iGearScanTip:Hide();
	
	return equipped, cost;
end

function iGear:GetItemDurability(slot)
	-- no durability if item has no durability on it
	if( not slot.canRepair ) then
		return;
	end
	
	-- if the item is broken, durability automatically is 0!
	if( _G.GetInventoryItemBroken("player", slot.id) ) then
		return 0;
	end
	local current, maximum = _G.GetInventoryItemDurability(slot.id);
	
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

function iGear:GetItemEnchant(slot)
	local _, _, enchant = string.find(slot.link, "item:%d+:(%d)");
	return tonumber(enchant);
end

function iGear:ScanBagsForRepCosts(scanBank)
	local _, current, maximum, repair, bags;
	
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
			
			-- as of 5.1, scanning the tooltip doesn't return repaircosts for bank items...
			-- so we hack around this
			if( scanBank and not repair ) then repair = 1 end
			
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

do
	local ICON_GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:1|t";
	local ICON_SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:1|t";
	local ICON_COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:1|t";

	function iGear:FormatMoney(money, standing)
		local discount = self:GetRepairDiscount(standing);
		
		-- add discount by reputation
		money = money * discount;
		
		local str, gold, silver, copper;
		money = floor(money); -- round up money
		
		-- borrowed the code from iMoney
		gold = floor(money / (100 * 100));
		silver = floor((money - (gold * 100 * 100)) / 100);
		copper = mod(money, 100);
		
			str	= (gold > 0 and _G.BreakUpLargeNumbers(gold).." "..ICON_GOLD or "")..
					  ((silver > 0 and gold > 0) and " " or "")..
						(silver > 0 and (silver < 10 and "0" or "")..silver.." "..ICON_SILVER or "")..
						((copper > 0 and silver > 0) and " " or "")..
						(copper > 0 and (copper < 10 and "0" or "")..copper.." "..ICON_COPPER or "");
		
		-- this may happen, tricky one!			
		if( str == "" ) then
			str = copper.." "..ICON_COPPER;
		end
		
		return str;
	end
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

local function LineEnter(anchor, slotID)
	_G.GameTooltip:SetOwner(anchor, "ANCHOR_BOTTOMRIGHT", 10, anchor:GetHeight()+2);
	_G.GameTooltip:SetInventoryItem("player", slotID);
	_G.GameTooltip:Show();
end

local function LineLeave()
	_G.GameTooltip:ClearLines();
	_G.GameTooltip:Hide();
end

function iGear:UpdateTooltip(tip)
	tip:Clear();
	
	local line;
	local text_slot, text_conflict, text_durability, text_costs;
	
	local conflicts_rep   = self:GetNumConflicts("repair");
	local conflicts_norep = self:GetNumConflicts("repair", true);
	tip:SetColumnLayout(4, "LEFT", "LEFT", "LEFT", "RIGHT");
	
	if( LibStub("iLib"):IsUpdate(AddonName) ) then
		line = tip:AddHeader("");
		tip:SetCell(line, 1, "|cffff0000"..L["Addon update available!"].."|r", nil, "CENTER", 0);
	end
	
	line = tip:AddHeader("");
	tip:SetCell(line, 1, L["Equip"], nil, "LEFT", 0);
	
	for _, slot in ipairs(EquipSlots) do
		if( slot.mustEquip and self:GetNumSlotConflicts(slot) > 0 ) then
			
			text_slot = (COLOR_GOLD):format(L[slot.name]);
			
			if( conflicts_norep ) then
				text_conflict = self:GetSlotConflictText(slot);
			else
				text_conflict = "";
			end
			
			if( self:GetSlotConflict(slot, "repair") ) then
				text_durability = self:FormatDurability(slot.durability);
				text_costs = self:FormatMoney(slot.repair);
			else
				text_durability = "";
				text_costs = "";
			end
			
			line = tip:AddLine(text_slot, text_conflict, text_durability, text_costs);
			
			if( conflicts_rep > 0 and conflicts_norep == 0 ) then
				tip:SetCell(line, 1, text_slot, nil, "LEFT", 2);
			elseif( conflicts_rep == 0 and conflicts_norep > 0 ) then
				tip:SetCell(line, 2, text_conflict, nil, "LEFT", 0);
			end
			
			tip:SetLineScript(line, "OnEnter", LineEnter, slot.id);
			tip:SetLineScript(line, "OnLeave", LineLeave);
		end
	end
	
	if( BagRepairCosts > 0 or BankLowestDurability < 100 ) then -- as of 5.1, we need to check for durability of bank items
		tip:AddLine(" ");
		line = tip:AddHeader("");
		tip:SetCell(line, 1, L["Inventory"], nil, "LEFT", 0);
		
		if( BagRepairCosts > 0 ) then
			text_slot = (COLOR_GOLD):format(L["In Bags"]);
			text_durability = self:FormatDurability(BagLowestDurability);
			text_costs = self:FormatMoney(BagRepairCosts);
			
			line = tip:AddLine(text_slot, "", text_durability, text_costs);
			if( conflicts_norep == 0 ) then
				tip:SetCell(line, 1, text_slot, nil, "LEFT", 2);
			end
		end
		
		if( BankLowestDurability < 100 ) then
			text_slot = (COLOR_GOLD):format(L["At Bank"]);
			text_durability = self:FormatDurability(BankLowestDurability);
			text_costs = "";--self:FormatMoney(BankRepairCosts);
			
			line = tip:AddLine(text_slot, "", text_durability, text_costs);
			if( conflicts_norep == 0 ) then
				tip:SetCell(line, 1, text_slot, nil, "LEFT", 2);
			end
		end
	end
	
	-- total repair costs
	if( conflicts_rep > 0 ) then
		tip:AddLine(" ");
		line = tip:AddHeader("");
		tip:SetCell(line, 1, L["Total Cost"], nil, "LEFT", 0);
		
		local c;
		
		for i = 8, 4, -1 do
			line = tip:AddLine("");
			c = _G.FACTION_BAR_COLORS[i];
			
			tip:SetCell(line, 1, ("|cff%02x%02x%02x%s|r"):format(c.r *255, c.g *255, c.b *255, _G["FACTION_STANDING_LABEL"..i]), nil, "LEFT", 3);
			tip:SetCell(line, 4, self:FormatMoney( (RepairCosts + BagRepairCosts), i), nil, "RIGHT");
			
			if( self:GetRepairDiscount(nil, true) == i ) then
				tip:SetLineColor(line, c.r, c.g, c.b, 0.4);
			end
		end
	end
end

---------------------
-- Final stuff
---------------------

_G.StaticPopupDialogs["IGEAR_AUTOREPAIR"] = {
	preferredIndex = 3, -- apparently avoids some UI taint
	button1 = _G.PLAYER,
	button2 = _G.CANCEL,
	button3 = _G.GUILD,
	showAlert = 1,
	timeout = 0,
	hideOnEscape = true,
	OnShow = function(self)
		if( not iGear:MerchantCanGuildRepair() ) then
			self.button3:Disable();
		end
	end,
	OnAccept = function()
		iGear:MerchantDoRepair();
	end,
	OnAlt = function()
		iGear:MerchantDoGuildRepair();
	end,
};