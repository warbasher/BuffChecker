-- For some reason druids return false on UnitIsDead("player")
-- They also have 1 health when in ghost form.
function BuffChecker.IsDead()
	return (UnitHealth("player") <= 1)
end

-- Quick function to check if someone is 'mounted'
local isDruid, druidCheck
function BuffChecker.IsMounted()
	if (not druidCheck) then
		druidCheck = true
		isDruid = (UnitClass("player") == "Druid")
	end

	if isDruid then
		if (AuraUtil.FindAuraByName("Flight Form", "player") or AuraUtil.FindAuraByName("Swift Flight Form", "player")) then return true end
	end

	return IsMounted("player")
end

function BuffChecker.TableCount(tab)
	if (not tab) then return 0 end

	local count = 0
	for _ in pairs(tab) do
		count = count + 1
	end

	return count
end

-- Taken from Monolith.
function BuffChecker:LoadSpec()
	local talentTrees = {}
	for i=1, 3 do
		table.insert(talentTrees, {GetTalentTabInfo(i)})
	end

	table.sort(talentTrees, function(a, b)
		return a[3] > b[3]
	end)

	local roleName = talentTrees[1][4]
	BuffChecker.CurrentSpec = roleName
end

-- Combat check is already called in checkButtons().
function BuffChecker:ShouldNotDisplay()
	return (IsResting("player") or UnitIsAFK("player") or self.IsMounted() or UnitOnTaxi("player") or self.IsDead())
end

function BuffChecker:GetMessageDelay()
	return (self.InInstance and self.Delays.Instance) or self.Delays.Overworld
end

function BuffChecker.SendNotification(message)
	DEFAULT_CHAT_FRAME:AddMessage("|c00a400ffBuff Checker:|r |c00ff0000"..message.."|r")
	RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
	PlaySound(8959)

	-- Current red: c00ff0000
	-- Light red color: c00ff6060
	--PlaySoundFile(552503)
end

function BuffChecker:ShouldNotify(buffTab)
	if IsResting("player") or UnitIsAFK("player") then return end
	local itemRequired = buffTab.RequiresItem
	if itemRequired and (GetItemCount(itemRequired) <= 0) then return end
	if buffTab.RaidOnly and (not UnitInRaid("player")) then return end

	local itemTab = buffTab.ItemsToCheck
	if itemTab then
		local hasItem
		for _, itemName in pairs(itemTab) do
			if (GetItemCount(itemName) > 0) then
				hasItem = true
				break
			end
		end
		if (not hasItem) then return end
	end

	return (buffTab.InstanceOnly and self.InInstance) and (not InCombatLockdown()) or (not buffTab.InstanceOnly)
end

function BuffChecker.SeparateWords(list)
	local display
	local numItems = #list
	for i=1, numItems do
		local name = list[i]
		if (not display) then
			display = name
		elseif (i == numItems) then
			if (numItems == 2) then
				display = display.." and "..name
			else
				display = display..", and "..name
			end
		else
			display = display..", "..name
		end
	end

	return display
end