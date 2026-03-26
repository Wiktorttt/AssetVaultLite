-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local RMB = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets
type mainSchema = typeof(ASSETS.AV_Main)
-----------------------------
-- SERVICES --
-----------------------------
local TS = game:GetService("TweenService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local App = require(MODULES.Core.AppState)
local Signals = require(MODULES.API.Signals)
local Pathfinder = require(MODULES.UI.Pathfinder)
local Dragger = require(MODULES.UI.Dragger)
local Vault = require(MODULES.Core.VaultData)

-----------------------------
-- CONSTANTS --
-----------------------------
local BUTTON_INFO = TweenInfo.new(.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ALLOWED_COPY_CLASSES = {
	SurfaceAppearance = "ColorMapContent",
	Decal = "ColorMapContent",
	Texture = "ColorMapContent",
	Sound = "SoundId"
}

-----------------------------
-- VARIABLES --
-----------------------------
local MAIN_DATA = Pathfinder:get("MAIN")
local mainGui : mainSchema = MAIN_DATA.UI

local pluginIns : Plugin = nil

local currentSettings = App.getSettings()
local currentSource = App.getSource()

local RMBOverlay = mainGui.Main.CurrentLibrary.RMBOverlay
local GRID_SCROLL = mainGui.Main.CurrentLibrary.Grid
local RMBGui = RMBOverlay.RMBGui


local deleteButton = RMBGui.Delete.buttonText.button
local moveToButton = RMBGui.moveTo.buttonText.button
local renameButton = RMBGui.Rename.buttonText.button
local favoriteButton = RMBGui.Favorite.buttonText.button
local copyButton = RMBGui.Copy.buttonText.button

local renameGui = RMBOverlay.RenameGui
local renameSubmit = renameGui.ButtonsFrame.submitButton
local renameCancel = renameGui.ButtonsFrame.closeButton
local renameBox = renameGui.renameBox
local renameNumberSwitch = renameGui.Switch.switchFrame.ButtonDot

local moveToGui = RMBOverlay.moveGui
local moveToBtnTemplate = moveToGui.buttonTEMP

local copyGui = RMBOverlay.copyGui
local copyBox = copyGui.copyBox
local copyClose = copyGui.closeButton

local savedInstances = {}
local saved

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function truncateText(str)
	if #str > 16 then
		str = string.gsub(str, "-", " ")
		str = string.gsub(str, "_", " ")
		str = string.sub(str, 1, 13).."..."
	end
	
	return str
end

local function copyAssetBasedOnInstance(ins:Instance)
	local found
	for key, val in ALLOWED_COPY_CLASSES do
		if ins.ClassName == key then
			found = ins[val]
			if typeof(found == "Content") then found = found.Uri end
			return found
		end
	end
	return found
end

-----------------------------
-- MAIN --
-----------------------------
-- Openings
local function openRMB(position:Vector3)
	RMBGui.Delete.Visible = (currentSource ~= "FAVORITES" and currentSource ~= "RECENT")
	RMBGui.moveTo.Visible = (currentSource ~= "FAVORITES" and currentSource ~= "RECENT")
	RMBGui.Favorite.buttonText.Text = currentSource == "FAVORITES" and "Unfavorite" or "Favorite"
	
	local instances = Dragger.getSelectedInstances()
	local canCopy = false
	if #instances == 1 then
		local targetInstance = instances[1]
		if targetInstance then
			for key, _ in ALLOWED_COPY_CLASSES do
				if targetInstance.ClassName == key then canCopy = true end
			end
		end
	end
	RMBGui.Copy.Visible = canCopy
	
	
	
	local relX = position.X - RMBOverlay.AbsolutePosition.X
	local relY = position.Y - RMBOverlay.AbsolutePosition.Y
	
	local menuWidth = RMBGui.AbsoluteSize.X
	local menuHeight = RMBGui.AbsoluteSize.Y
	
	local containerWidth = RMBOverlay.AbsoluteSize.X
	local containerHeight = RMBOverlay.AbsoluteSize.Y
	
	if relX + menuWidth > containerWidth then
		relX -= menuWidth
	end

	if relY + menuHeight > containerHeight then
		relY -= menuHeight
	end
	
	RMBGui.Position = UDim2.fromOffset(relX, relY)
	RMBGui.Visible = true
end

local function closeRMB()
	RMBGui.Visible = false
end

local function openRename()
	renameGui.Visible = true
	renameSubmit.Text = #savedInstances == 1 and "Rename" or "Rename All"

end

local function closeRename()
	renameGui.Visible = false
end

local function closeMoveTo()
	moveToGui.Visible = false
	for _, obj in moveToGui:GetChildren() do
		if obj:IsA("GuiObject") and obj.Name == "button" then obj:Destroy() end
	end
end

local function openMoveTo()
	for _, data in Vault.getLibrariesWithChildren() do
		local btnClone = moveToBtnTemplate:Clone()
		btnClone.Name = "button"
		btnClone.Text = data.Name
		btnClone.Visible = true
		
		btnClone.Activated:Connect(function()
			local changed = false
			for _, merged in savedInstances do
				local frame = merged[1]
				local ins = merged[2]
				if ins and ins.Parent ~= data.Instance then
					ins.Parent = data.Instance
					if frame then frame:Destroy() end
					changed = true
				end
			end
			if changed then ChangeHistoryService:SetWaypoint("Moved AssetVault Instances") end
			closeMoveTo()
		end)
		
		btnClone.Parent = moveToGui
	end
	
	local new = (#moveToGui:GetChildren() - 6) * .2 + .8
	moveToGui.CanvasSize = UDim2.fromScale(0, new)
	
	moveToGui.Visible = true
end

local function openCopy()
	local instance = Dragger.getSelectedInstances()
	if #instance ~= 1 then closeRMB() return end
	local allowed = false
	for key, _ in ALLOWED_COPY_CLASSES do
		if instance[1].ClassName == key then allowed = true end
	end
	if not allowed then closeRMB() return end
	
	copyBox.Text = copyAssetBasedOnInstance(instance[1]) or "NOT FOUND"
	
	closeRMB()
	
	copyGui.Visible = true
end

local function closeCopy()
	copyBox.Text = ""
	copyGui.Visible = false
end

--Functionality
local function rename()
	local data = Dragger.getSelectedInstances(true)
	if #data == 0 then closeRMB() return end
	
	savedInstances = data
	closeRMB()
	if #data > 0 then
		openRename()
	end
end

local function renameSubmitFunc()
	local chosenText = string.gsub(renameBox.Text, "[;,'\"~`]", "")
	if #savedInstances == 0 or chosenText == "" then closeRename() return end
	
	local shouldAutoNumber = currentSettings.AutoAddNumbers or false
	
	for i, data in savedInstances do
		local frame = data[1]
		local instance = data[2]
		local convertedText = shouldAutoNumber and chosenText..` {i}` or chosenText
		if frame then
			frame.TextLabel.Text = truncateText(convertedText)
		end
		if instance and instance.Parent then
			instance.Name = convertedText
		end
	end
	
	ChangeHistoryService:SetWaypoint("Renamed AssetVault Instances")
	closeRename()
end

local function moveTo()
	local data = Dragger.getSelectedInstances(true)
	if #data == 0 then closeRMB() return end
	
	savedInstances = data
	closeRMB()
	if #data > 0 then
		openMoveTo()
	end
end

local function favorite()
	local data = Dragger.getSelectedInstances(true)
	if #data == 0 then closeRMB() return end
	for _, single in data do
		local frame = single[1]
		local instance = single[2]
		if instance:HasTag("AV_FAVORITED") then
			if currentSource == "FAVORITES" then
				frame:Destroy()
			else
				frame.Star.Visible = false
			end
			instance:RemoveTag("AV_FAVORITED")
		else
			frame.Star.Visible = true
			instance:AddTag("AV_FAVORITED")
		end
	end
	closeRMB()
end

local function delete()
	local data = Dragger.getSelectedInstances(true)
	if #data == 0 then closeRMB() return end
	local changed = false
	for _, single in data do
		local frame = single[1]
		local instance = single[2]
		if instance then instance.Parent = nil end
		if frame then frame:Destroy() end
		changed = true
	end
	
	if changed then ChangeHistoryService:SetWaypoint("Deleted AssetVault Instances") end
	
	closeRMB()
end

-----------------------------
-- INIT --
-----------------------------
local function init()
	RMBOverlay.InputEnded:Connect(function(input:InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			closeRMB()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			openRMB(input.Position)
		end
	end)
end

init()

-----------------------------
-- CONNECTIONS --
-----------------------------
favoriteButton.Activated:Connect(favorite)
renameButton.Activated:Connect(rename)
moveToButton.Activated:Connect(moveTo)
deleteButton.Activated:Connect(delete)
copyButton.Activated:Connect(openCopy)

renameSubmit.Activated:Connect(renameSubmitFunc)
renameCancel.Activated:Connect(closeRename)

copyClose.Activated:Connect(closeCopy)

Signals.settingsChanged:Connect(function(newSettings)
	currentSettings = newSettings
end)
Signals.sourceChanged:Connect(function(newSource)
	currentSource = newSource
end)
return RMB
