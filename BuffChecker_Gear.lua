-- Functions to make table setup easier.
local function tableIsAssoc(t)
	for _, v in pairs(t) do
		if (v == true) then return true end
		return false
	end
end

local function tableToAssoc(t)
	if not tableIsAssoc(t) then
		local t2 = {}
		for k, v in pairs(t) do
			t2[v] = true
		end

		return t2
	end

	return t
end

function BuffChecker.TableCopy(tbl)
	if (type(tbl) ~= "table") then return tbl end

	local t = {}
	for k, v in pairs(tbl) do
		t[k] = tablecopy(v)
	end

	return t
end

-- Settings for checking gear. Only checks in instances.
local nameToSlotID = {
	["Trinkets"] = {INVSLOT_TRINKET1, INVSLOT_TRINKET2},
}
local gearToRemove = {
	["Trinkets"] = tableToAssoc({"Riding Crop", "Carrot on a Stick", "Skybreaker Whip"}),
}

local slotsToCheck = {}
for _, tab in pairs(nameToSlotID) do
	for _, slotID in pairs(tab) do
		slotsToCheck[slotID] = true
	end
end

local nextCheck = 0
local gearTimer
function BuffChecker.CheckGear(slotID)
	if (not BuffChecker.InInstance) then return end
	if slotID and (not slotsToCheck[slotID]) then return end
	if (nextCheck > GetTime()) then return end

	local gearList = {}
	for slotName, items in pairs(gearToRemove) do
		local slotTab = nameToSlotID[slotName]
		for i=1, #slotTab do
			local slotID = slotTab[i]
			local link = GetInventoryItemLink("player", slotID)
			if link then
				local name = GetItemInfo(link) or ""
				if items[name] then
					table.insert(gearList, name)
				end
			end
		end
	end

	BuffChecker.NotificationList.Gear = gearList
	BuffChecker.EvaluateTextCol()

	if (#gearList > 0) then
		local timerDelay = BuffChecker.EvalDelay
		nextLowBuffCheck = GetTime() + timerDelay
		C_Timer.After(timerDelay, checkForLowBuffs)
	end
end

local frame = BuffChecker.Frame
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame["PLAYER_EQUIPMENT_CHANGED"] = function(self, slotID)
	BuffChecker.CheckGear(slotID)
end