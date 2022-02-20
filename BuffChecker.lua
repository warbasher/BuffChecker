BuffChecker = {}
BuffChecker.Enabled = true
BuffChecker.InInstance = false
BuffChecker.EvalDelay = 1
BuffChecker.Delays = {
	Instance = 20,
	Overworld = 30
}
BuffChecker.MinBuffTime = 8 -- In minutes
BuffChecker.BossReminders = false -- Gets set to true if we have settings that require boss reminders.
BuffChecker.Loaded = false
BuffChecker.NotificationList = {
	Buffs = {},
	Gear = {},
	LowItems = {},
	LowBuffs = {},
}
-- BuffChecker.ActiveTab -- Gets set to one of the buffsToCheck depending on your class.

-- Idea: warn you if there's a shaman in your group and you move too far away.
-- Same with boomkin.

-- Local variables.
local buttonCount = 0
local activeButtons = {}
local forcedLoadTime = 3
local nextCheck = GetTime() + 5
local lastAfk, lastMounted, checkInWorld

local classRoles = {
	["Caster"] = {"Mage", "Warlock"},
	--["Spriest"] = {"PriestShadow"},
	["ProtPally"] = {"PaladinProtection"},
}
local consumeChecks = {
	["Caster"] = {
		["Flask"] = {
			InstanceOnly = true,
			BossOnly = true,
			RaidOnly = true,
			SpellsToCheck = {
				"Supreme Power", "Flask of Pure Death",
				"Flask of Blinding Light",
				"Supreme Power of Shattrath",
				"Pure Death of Shattrath",
				"Blinding Light of Shattrath",
			},
			ItemsToCheck = {
				"Flask of Supreme Power", "Flask of Pure Death",
				"Flask of Blinding Light",
				"Shattrath Flask of Supreme Power",
				"Shattrath Flask of Pure Death",
				"Shattrath Flask of Blinding Light",
			},
		},
		["Oil"] = {
			InstanceOnly = true,
			BossOnly = true,
			RaidOnly = true,
			CheckWeapon = true,
			ItemsToCheck = {"Superior Wizard Oil", "Brilliant Wizard Oil"},
		},
		["Food"] = {
			InstanceOnly = true,
			BossOnly = true,
			RaidOnly = true,
			SpellsToCheck = {"Well Fed"},
			ItemsToCheck = {
				"Poached Bluefish", "Blackened Basilisk",
				"Crunchy Serpent", "Skullfish Soup"
			},
		},
	},

	["ProtPally"] = {
		["Flask"] = {
			InstanceOnly = true,
			BossOnly = true,
			RaidOnly = true,
			SpellsToCheck = {
				"Supreme Power", "Flask of Blinding Light",
				"Flask of Fortification", "Flask of the Titans",
				"Supreme Power of Shattrath",
				"Blinding Light of Shattrath",
				"Fortification of Shattrath",
			},
			ItemsToCheck = {
				"Flask of Supreme Power", "Flask of Blinding Light",
				"Flask of Fortification", "Flask of the Titans",
				"Shattrath Flask of Supreme Power",
				"Shattrath Flask of Blinding Light",
				"Shattrath Flask of Fortification",
			},
		},
		["Oil"] = {
			InstanceOnly = true,
			BossOnly = true,
			RaidOnly = true,
			CheckWeapon = true,
			ItemsToCheck = {
				"Superior Wizard Oil", "Brilliant Wizard Oil",
				"Superior Mana Oil", "Brilliant Mana Oil"
			},
		},
		["Food"] = {
			InstanceOnly = true,
			BossOnly = true,
			RaidOnly = true,
			SpellsToCheck = {"Well Fed"},
			ItemsToCheck = {
				"Poached Bluefish", "Blackened Basilisk",
				"Crunchy Serpent", "Skullfish Soup",
				"Grilled Mudfish", "Fisherman's Feast",
				"Talbuk Steak", "Spicy Crawdad",
				"Hot Apple Cider", "Buzzard Bites"
			},
		},
	}
}

-- Settings for checking buffs.
local buffsToCheck = {
	["Mage"] = {
		["Mage/Molten Armor"] = {
			SpellsToCheck = {"Mage Armor", "Molten Armor", "Ice Armor"},
			InstanceOnly = true,
			ShowButtons = true,
			RemindForBoss = true,
		},
		["Arcane Intellect"] = {
			SpellsToCheck = {"Arcane Intellect", "Arcane Brilliance"},
			InstanceOnly = true,
			ShowButtons = true,
			RemindForBoss = true,
		},
	},

	["Paladin"] = {
		["Righteous Fury"] = {
			SpellsToCheck = {"Righteous Fury"},
			InstanceOnly = true,
			RemindForBoss = true,
			RequiredSpec = "PaladinProtection",
		},
	},

	["Warlock"] = {
		["Fel/Demon Armor"] = {
			SpellsToCheck = {"Fel Armor", "Demon Armor"},
			InstanceOnly = true,
			RemindForBoss = true,
		},
		--["Demonic Sacrifice"] = {
		["Pet Buff"] = {
			SpellsToCheck = {
				"Burning Wish", "Fel Stamina", "Touch of Shadow",
				"Fel Energy", "Touch of Shadow", "Blood Pact",
				"Demonic Knowledge", "Paranoia"},
			CheckPet = true,
			InstanceOnly = true,
			RemindForBoss = true,
			RequiresItem = "Soul Shard",
		},
	},

	["Druid"] = {
		--[[["Thorns"] = {
			SpellsToCheck = {"Thorns"},
			InstanceOnly = true,
			ShowButtons = true,
			RequiredSpec = "DruidFeralCombat"
		},]]
		["Mark of the wild"] = {
			SpellsToCheck = {"Mark of the Wild", "Gift of the Wild"},
			InstanceOnly = true,
			ShowButtons = true,
			RequiredSpec = "DruidFeralCombat"
		},
		["Omen of clarity"] = {
			SpellsToCheck = {"Omen of Clarity"},
			InstanceOnly = true,
			ShowButtons = true,
			RequiredSpec = "DruidFeralCombat"
		},
	},
}

-- These are only checked when a boss is targeted.
local itemsToCheck = {
	["Mage"] = {
		["Mana Emerald"] = {
			Count = 3,
			HasCharges = true,
			InstanceOnly = true,
		},
	},
	["Warlock"] = {
		["Master Healthstone"] = {
			Count = 1,
			InstanceOnly = true,
			RequiresItem = "Soul Shard",
		}
	}
}

function getRoleName()
	-- First, search for specialized specs.
	local playerClass = UnitClass("player")
	local curSpec = BuffChecker.CurrentSpec
	for role, classTab in pairs(classRoles) do
		for _, className in pairs(classTab) do
			if (curSpec == className) then
				return role
			end
		end
	end

	-- Repeat and look for general specs.
	local roleName
	local curSpec = BuffChecker.CurrentSpec
	for role, classTab in pairs(classRoles) do
		for _, className in pairs(classTab) do
			if (playerClass == className) then
				return role
			end
		end
	end

	return nil
end
local function variablesLoaded()
	BuffChecker:LoadSpec()

	local useBossReminders
	local playerClass = UnitClass("player")
	for class, buffTab in pairs(buffsToCheck) do
		if (playerClass == class) then
			-- Get a copy instead of a reference.
			BuffChecker.ActiveTab = {}
			for k, v in pairs(buffTab) do
				BuffChecker.ActiveTab[k] = v
			end

			local tab = BuffChecker.ActiveTab
			-- See if certain checks require a spec.
			local toRemove = {}
			for buffName, buffTab in pairs(tab) do
				local reqSpec = buffTab.RequiredSpec
				if reqSpec and (BuffChecker.CurrentSpec ~= reqSpec) then
					table.insert(toRemove, buffName)
				end
			end

			-- Remove those checks if we don't meet the spec requirement.
			if (#toRemove > 0) then
				for _, name in pairs(toRemove) do
					tab[name] = nil
				end
			end

			-- Setup boss reminder variable.
			for _, buffTab in pairs(tab) do
				if buffTab.RemindForBoss then
					useBossReminders = true
					break
				end
			end

			break
		end
	end

	for class, tab in pairs(itemsToCheck) do
		if (playerClass == class) then
			BuffChecker.ItemTab = tab
			useBossReminders = true
			break
		end
	end

	if BuffChecker.ActiveTab then
		-- Insert the consume checks we need.
		local roleName = getRoleName()
		if roleName then
			local consumeTab = consumeChecks[roleName]
			if consumeTab then
				for key, value in pairs(consumeTab) do
					BuffChecker.ActiveTab[key] = value
				end
			end
		end

		-- Set up a variable if we're going to be checking stuff in the world.
		for _, spellTab in pairs(BuffChecker.ActiveTab) do
			if (not spellTab.InstanceOnly) then
				checkInWorld = true
			end
		end
	end

	BuffChecker.Enabled = ((BuffChecker.TableCount(BuffChecker.ActiveTab) > 0) and (UnitLevel("player") >= 60))
	--BuffChecker.Enabled = (BuffChecker.TableCount(BuffChecker.ActiveTab) > 0)
	if (not BuffChecker.Enabled) then
		BuffChecker.VisualFrame:Hide()

		-- Unregister the events.
		BuffChecker.Frame:SetScript("OnEvent", nil)
	end

	lastAfk = UnitIsAFK("player")
	lastMounted = BuffChecker.IsMounted()

	if useBossReminders then
		-- Register the boss reminder events.
		BuffChecker.RegisterBossReminders()
	end

	nextCheck = 0
end

local function checkButtons()
	if (not BuffChecker.Loaded) then return end
	if (buttonCount == 0) then return end
	if InCombatLockdown() then return end

	local toHide = {}
	for name, btnTab in pairs(activeButtons) do
		for _, btn in pairs(btnTab) do
			if btn:HasBuff() or BuffChecker:ShouldNotDisplay() then
				table.insert(toHide, name)
				break
			end
		end
	end

	local indexRemoved
	local removedSomething = false
	for _, name in pairs(toHide) do
		for _, btn in pairs(activeButtons[name]) do
			-- Only shift if we didn't remove the very leftmost (max) element.
			if (btn.Index ~= (buttonCount - 1)) then
				indexRemoved = btn.Index
			end
			btn:Hide()
		end

		buttonCount = buttonCount - 1
		activeButtons[name] = nil
		removedSomething = true
	end

	-- Shift the other buttons over.
	if removedSomething and indexRemoved then
		for name, btnTab in pairs(activeButtons) do
			for index, btn in pairs(btnTab) do
				if (btn.Index ~= 0) then
					btn.Index = btn.Index - 1
				end
				local offset = (btn.Index * 35)
				btn:SetPoint("CENTER", offset, index * 35)
			end
		end
	end
end

local function getMissingBuffs()
	local missingBuffs = {}
	for name, buffTab in pairs(BuffChecker.ActiveTab) do
		-- All because wow doesn't support 'continue' from lua, great job. Let's have 1000 tabs over.
		local shouldCheck = BuffChecker:ShouldNotify(buffTab)
		if shouldCheck and (not buffTab.BossOnly) then -- Clean this up later.
			local toCheck = buffTab.SpellsToCheck
			if (not toCheck) then print("Spells are missing for: "..name) break end

			local buffCount = #toCheck
			local missingBuffCount = 0
			for _, buffName in pairs(toCheck) do
				local BuffExists = AuraUtil.FindAuraByName(buffName, "player")
				if (not BuffExists) then
					missingBuffCount = missingBuffCount + 1
				end
			end

			local missingAllBuffs = (missingBuffCount == buffCount)
			if missingAllBuffs then
				-- Backup for the warlock stuff. Rewrite this later.
				local shouldAdd = true
				if buffTab.CheckPet then
					if UnitHealth("pet") > 0 then shouldAdd = false end
				end

				if shouldAdd then
					table.insert(missingBuffs, name)
				end
			end
		end

		if BuffChecker.BossSelected and shouldCheck and buffTab.BossOnly then
			local toCheck = buffTab.SpellsToCheck
			if toCheck then
				local buffCount = #toCheck
				local missingBuffCount = 0
				for _, buffName in pairs(toCheck) do
					local BuffExists = AuraUtil.FindAuraByName(buffName, "player")
					if (not BuffExists) then
						missingBuffCount = missingBuffCount + 1
					end
				end

				local missingAllBuffs = (missingBuffCount == buffCount)
				if missingAllBuffs then
					table.insert(missingBuffs, name)
				end
			end
	
			if buffTab.CheckWeapon then
				local hasEnchant = GetWeaponEnchantInfo()
				if (not hasEnchant) then
					table.insert(missingBuffs, name)
				end
			end
		end
	end
	return missingBuffs
end

function BuffChecker:CheckBuffs(override)
	if (not self.Loaded) then return end

	if (not override) and 
		((not self.ActiveTab) or (nextCheck > GetTime())) then return end

	if self:ShouldNotDisplay() then
		BuffChecker.NotificationList.Buffs = {}
		return
	end

	local missingBuffs = getMissingBuffs()

	BuffChecker.NotificationList.Buffs = missingBuffs
	BuffChecker.EvaluateTextCol()

	local numBuffsMissing = #missingBuffs
	if (numBuffsMissing > 0) then
		local toDisplay
		for i=1, numBuffsMissing do
			local name = missingBuffs[i]
			local buffTab = self.ActiveTab[name]
			local toCheck = buffTab.SpellsToCheck
			if (not InCombatLockdown()) and buffTab.ShowButtons and (not activeButtons[name]) then
				local btnTab = {}
				for index, buffName in pairs(toCheck) do
					local alreadyExists = _G[buffName]
					local btn = _G[buffName] or CreateFrame("Button", buffName, nil, "SecureActionButtonTemplate");
					btn:RegisterForClicks("AnyUp")
					btn:SetAttribute("type", "spell")
					btn:SetAttribute("spell", buffName)
					btn:SetAttribute("unit", "player")

					local spellName, _, icon, _, _, _, spellID = GetSpellInfo(buffName)
					btn:SetPushedTexture(icon)
					btn:SetHighlightTexture(icon)
					btn:SetNormalTexture(icon)
					local offset = (buttonCount * 35)
					btn.Index = buttonCount
					btn:SetPoint("CENTER", offset, index * 35)
					btn:SetSize(35, 35)
					btn.DisplayedMessage = false
					btn.HasBuff = function(self)
						return AuraUtil.FindAuraByName(buffName, "player")
					end
					btn:SetScript("OnUpdate", function(self)
						local hasBuff = self:HasBuff()
						if (hasBuff or BuffChecker:ShouldNotDisplay()) then
							if hasBuff and (not self.DisplayedMessage) then
								DEFAULT_CHAT_FRAME:AddMessage("|c00a400ffBuff Checker:|r |c0000ff00Applied "..buffName..".|r")
								self.DisplayedMessage = true
							end

							checkButtons()
						end
					end)
					btn:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
						GameTooltip:SetSpellByID(spellID)
						GameTooltip:Show()
					end)
					btn:SetScript("OnLeave",
						function(self) GameTooltip:Hide()
					end)
					btn:Show()

					table.insert(btnTab, btn)
				end

				buttonCount = buttonCount + 1
				activeButtons[name] = btnTab
			end
		end

		if (not override) then
			local timerDelay = BuffChecker.EvalDelay
			nextLowBuffCheck = GetTime() + timerDelay
			C_Timer.After(timerDelay, function() self:CheckBuffs() end)
		end

		return true
	end
end

local function checkInstance()
	BuffChecker.InInstance = IsInInstance()
end

local function handleEvent(self, event, ...)
	local handlerMethod = self[event]
	if handlerMethod then
		handlerMethod(self, ...)
	end
end
local frame = CreateFrame("Frame", "EventsFrame")
frame:SetScript("OnEvent", handleEvent)
BuffChecker.Frame = frame

frame:RegisterEvent("ADDON_LOADED")
frame["ADDON_LOADED"] = function(self)
	--[[if (not GetSpecialization) then -- Why the fuck is this not initialized?
		C_Timer.After(1, function()
			frame["ADDON_LOADED"](self)
		end)
	else]]
		variablesLoaded()
		self:UnregisterEvent("ADDON_LOADED")

		C_Timer.After(forcedLoadTime, function()
			BuffChecker.Loaded = true
			self["PLAYER_ENTERING_WORLD"]()
		end)
	--end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame["PLAYER_ENTERING_WORLD"] = function(self)
	-- Slightly delay the check until we're in, if we check instantly we have nothing.
	C_Timer.After(2.5, function()
		checkInstance()
		-- These two will loop.
		BuffChecker:CheckBuffs()
		BuffChecker.CheckGear()
	end)
end

frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame["PLAYER_REGEN_ENABLED"] = function(self)
	checkButtons()
end

frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
frame["CHARACTER_POINTS_CHANGED"] = function(self)
	-- Reload the variables/active tab/etc
	variablesLoaded()
end

frame:RegisterEvent("UNIT_AURA")
frame["UNIT_AURA"] = function(self, unit)
	if (unit ~= "player") then return end
	local displayedMissingBuffs = BuffChecker:CheckBuffs()

	-- Check to see if we gained/lost mounted buff
	if (not checkInWorld) then return end

	-- Since flying is a buff, check for that.
	local curMounted = isMounted()
	if (curMounted == lastMounted) then return end
	lastMounted = curMounted

	-- Re-check buttons so we can disable them if we are flying.
	checkButtons()
	-- If we didn't just display a missing buff message, and we stopped flying, send a message.
	if (not displayedMissingBuffs) and (not curMounted) then
		BuffChecker:CheckBuffs(true)
	end
end

frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame["PLAYER_UPDATE_RESTING"] = function(self)
	if (not checkInWorld) then self:UnregisterEvent("PLAYER_UPDATE_RESTING") return end

	-- Re-check buttons so we can disable them once we become rested.
	checkButtons()
	-- Check buffs in case we just left a rested area.
	BuffChecker:CheckBuffs(true)
end

frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
frame["PLAYER_FLAGS_CHANGED"] = function(self, unit)
	if (not checkInWorld) then self:UnregisterEvent("PLAYER_FLAGS_CHANGED") return end
	if (unit ~= "player") then return end

	-- Only check this if our afk status changes.
	local curAfk = UnitIsAFK("player")
	if (curAfk == lastAfk) then return end
	lastAfk = curAfk

	-- Re-check buttons so we can disable them if we are afk.
	checkButtons()
	BuffChecker:CheckBuffs(true)
end

-- Flight path checks.
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame["PLAYER_CONTROL_GAINED"] = function(self)
	if (not checkInWorld) then self:UnregisterEvent("PLAYER_CONTROL_GAINED") return end
	checkButtons()
	BuffChecker:CheckBuffs(true)
end

frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame["PLAYER_CONTROL_LOST"] = function(self)
	if (not checkInWorld) then self:UnregisterEvent("PLAYER_CONTROL_LOST") return end
	checkButtons()
	BuffChecker:CheckBuffs(true)
end
