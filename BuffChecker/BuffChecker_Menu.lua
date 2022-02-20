BuffCheckerMenu = {}

local profileTab
local frame = CreateFrame("Frame", "BuffCheckerFrame", UIParent, "BackdropTemplate")
frame:SetClampedToScreen(true)
frame:SetPoint("CENTER")
frame:SetSize(100, 100)
frame:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
})
frame:SetBackdropColor(0, 0, 0, 0.85)
BuffChecker.VisualFrame = frame

local function loadFramePosition()
	frame:ClearAllPoints()

	if profileTab and profileTab.Offset.x and profileTab.Offset.y then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", profileTab.Offset.x, profileTab.Offset.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

local function loadProfile()
	local name = UnitName("player")

	if (not BuffCheckerMenu.Profiles) then BuffCheckerMenu.Profiles = {} end
	if (not BuffCheckerMenu.Profiles[name]) then BuffCheckerMenu.Profiles[name] = {} end
	BuffCheckerMenu.Profiles[name] = BuffCheckerMenu.Profiles[name] or {}
	BuffCheckerMenu.Profiles[name].Offset = BuffCheckerMenu.Profiles[name].Offset or {}
	BuffCheckerMenu.Profiles[name].Muted = BuffCheckerMenu.Profiles[name].Muted

	profileTab = BuffCheckerMenu.Profiles[name]
end

local function saveFramePosition()
	profileTab.Offset.x = frame:GetLeft()
	profileTab.Offset.y = frame:GetTop()
end

local displaying = false
local locked = true
local dropDownFrame = CreateFrame("Frame", "BuffCheckerFrameDD")
local dropDownTab = {
	{
		text = "Lock menu",
		func = function()
			displaying = false
			locked = (not locked)
			frame:SetMovable(not locked)
			frame:RegisterForDrag(((not locked) and "LeftButton") or nil)
		end,
		checked = function() return locked end,
	},
	{
		text = "Mute messages",
		func = function()
			displaying = false
			profileTab.Muted = (not profileTab.Muted)
		end,
		checked = function() return profileTab.Muted end,
	},
	{
		text = CLOSE,
		func = function()
			displaying = false
			CloseDropDownMenus()
		end,
		notCheckable = 1,
	},
}

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function()
	frame:StopMovingOrSizing()
	saveFramePosition()
end)
frame:SetScript("OnMouseDown", function (self, button)
	if (button == "RightButton") then
		if displaying then
			displaying = false
			CloseDropDownMenus()
			return
		end

		displaying = true
		EasyMenu(dropDownTab, dropDownFrame, self:GetName(), 0, 0, nil)
	end
end)

local text = frame:CreateFontString(frame, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER", frame, "CENTER", 0, 0)
text:SetText("Buff Checker")
text:SetTextColor(0, 1, 0, 1)
frame:SetSize(text:GetStringWidth() * 1.2, text:GetStringHeight() * 1.75)

local nextCheck = 0
function BuffChecker.EvaluateTextCol()
	local totalCount = 0
	for _, tab in pairs(BuffChecker.NotificationList) do
		totalCount = totalCount + #tab
	end
	local missing = (totalCount > 0)
	text:SetTextColor((missing and 1) or 0, (missing and 0) or 1, 0)

	if missing then
		frame:SetScript("OnEnter", function()
			GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
			GameTooltip:AddLine("Buff Checker:")

			for _, name in pairs(BuffChecker.NotificationList.Buffs) do
				GameTooltip:AddLine("|c00ff0000Missing: |r "..name, 1, 1, 1)
			end
			for _, name in pairs(BuffChecker.NotificationList.LowBuffs) do
				GameTooltip:AddLine("|c00ff0000Duration low: |r "..name, 1, 1, 1)
			end
			for _, name in pairs(BuffChecker.NotificationList.LowItems) do
				GameTooltip:AddLine("|c00ff0000Low count: |r "..name, 1, 1, 1)
			end
			for _, name in pairs(BuffChecker.NotificationList.Gear) do
				GameTooltip:AddLine("|c00ff0000Item equipped: |r "..name, 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	else
		frame:SetScript("OnEnter", function() end)
		frame:SetScript("OnLeave", function() end)
	end

	if (nextCheck > GetTime()) then return end
	if missing and (not profileTab.Muted) then
		BuffChecker.SendNotification("You have a notification. Hover over 'Buff Checker' to view it.")
	end

	local timerDelay = BuffChecker:GetMessageDelay()
	nextCheck = GetTime() + timerDelay
	C_Timer.After(timerDelay, function() BuffChecker.EvaluateTextCol() end)
end

local events = CreateFrame("Frame", "BuffCheckerEventsFrame")
events:RegisterEvent("ADDON_LOADED")

local function BuffChecker_OnEvent(self, event, arg1, arg2, ...)
	if (event == "ADDON_LOADED") then
		self:UnregisterEvent("ADDON_LOADED")

		loadProfile()
		loadFramePosition()
	end
end

events:SetScript("OnEvent", BuffChecker_OnEvent)