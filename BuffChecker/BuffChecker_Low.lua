local function getBuffDuration(buffName)
	for i=1, 40 do
		local name, _, _, _, _, expirationTime = UnitBuff("player", i)
		if (not name) then return -1 end
		if (name == buffName) then
			-- Return minutes left.
			return (-1 * (GetTime() - expirationTime) / 60)
		end
	end

	return -1
end

local function getLowBuffs()
	local lowBuffs = {}
	for name, buffTab in pairs(BuffChecker.ActiveTab) do
		local shouldCheck = BuffChecker:ShouldNotify(buffTab)
		if shouldCheck and (buffTab.RemindForBoss or buffTab.BossOnly) then
			local toCheck = buffTab.SpellsToCheck
			local buffIsLow
			if toCheck then
				for _, buffName in pairs(toCheck) do
					local BuffExists = AuraUtil.FindAuraByName(buffName, "player")
					-- We only notify that a buff is low if it exists.
					if BuffExists then
						local timeLeft = getBuffDuration(buffName)
						buffIsLow = (timeLeft > -1) and (timeLeft < BuffChecker.MinBuffTime)
						break
					end
				end
			end

			if buffTab.CheckWeapon then
				local hasEnchant, expirationTime = GetWeaponEnchantInfo()
				if expirationTime then
					expirationTime = (expirationTime / 60000)
				end

				--print(expirationTime)
				buffIsLow = (hasEnchant and (expirationTime < BuffChecker.MinBuffTime))
			end

			if buffIsLow then
				table.insert(lowBuffs, name)
			end
		end
	end

	return lowBuffs
end

local function getLowItems()
	local lowItems = {}
	for name, itemTab in pairs(BuffChecker.ItemTab) do
		local shouldCheck = BuffChecker:ShouldNotify(itemTab)
		if shouldCheck then
			local itemCount = GetItemCount(name, nil, itemTab.HasCharges)
			if (itemCount < itemTab.Count) then
				table.insert(lowItems, name)
			end
		end
	end

	return lowItems
end

BuffChecker.BossSelected = false
local function shouldDisplayLowBuffs()
	return BuffChecker.BossSelected and (not BuffChecker:ShouldNotDisplay())
end
local nextLowBuffCheck = 0
local function checkForLowBuffs()
	if (not shouldDisplayLowBuffs()) then
		BuffChecker.NotificationList.LowBuffs = {}
		BuffChecker.NotificationList.LowItems = {}
		BuffChecker.EvaluateTextCol()
		return
	end
	if (nextLowBuffCheck > GetTime()) then return end

	BuffChecker.NotificationList.LowBuffs = getLowBuffs()
	BuffChecker.NotificationList.LowItems = getLowItems()
	BuffChecker.EvaluateTextCol()

	local timerDelay = BuffChecker.EvalDelay
	nextLowBuffCheck = GetTime() + timerDelay
	C_Timer.After(timerDelay, checkForLowBuffs)
end

local levelToCheck = -1
function BuffChecker.RegisterBossReminders()
	-- Should fire if ANYONE targets the boss.
	local frame = BuffChecker.Frame
	local bossName
	frame:RegisterEvent("UNIT_TARGET")
	frame["UNIT_TARGET"] = function(self, unitID)
		if InCombatLockdown() then return end -- Don't bother.

		local curBossVal = BuffChecker.BossSelected
		local target = unitID.."target"
		-- If the target is valid but dead, don't do anything.
		if UnitExists(target) and (UnitHealth(target) == 0) then return end
		if (UnitLevel(target) == levelToCheck) then
			bossName = UnitName(unitID.."target")
			BuffChecker.BossSelected = true
		end

		if BuffChecker.BossSelected then
			-- Now, search through and see if someone still has it targeted.
			local hasTarget
			for i=1, GetNumGroupMembers() do
				if IsInRaid() then
					if (UnitLevel("raid"..i.."target") == levelToCheck) then
						bossName = UnitName("raid"..i.."target")
						hasTarget = true
						break
					end
					-- Not functional?
				--[[else
					if (UnitLevel("party"..i.."target") == levelToCheck) then
						bossName = UnitName("party"..i.."target")
						hasTarget = true
						break
					end]]
				end
			end

			BuffChecker.BossSelected = hasTarget
			if (not hasTarget) then
				bossName = nil
			end
		end

		if (curBossVal ~= BuffChecker.BossSelected) then
			BuffChecker:CheckBuffs()
		end

		checkForLowBuffs()
	end

	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame["COMBAT_LOG_EVENT_UNFILTERED"] = function(self)
		if IsInRaid() then
			local _, eventName, _, _, _, _, _, _, name = CombatLogGetCurrentEventInfo()
			if (eventName == "UNIT_DIED") and (bossName == name) then
				BuffChecker.BossSelected = nil
				bossName = nil
			end
		end
	end
end