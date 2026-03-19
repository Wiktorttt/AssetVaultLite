-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local Bar = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets
type mainSchema = typeof(ASSETS.AV_Main)

-----------------------------
-- SERVICES --
-----------------------------
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Pathfinder = require(MODULES.UI.Pathfinder)
local App = require(MODULES.Core.AppState)
local Tree = require(MODULES.Components.TreeHandler)
local Signals = require(MODULES.API.Signals)

-----------------------------
-- VARIABLES --
-----------------------------
local MAIN_DATA = Pathfinder:get("MAIN")
local HELP_DATA = Pathfinder:get("HELP")
local mainGui : mainSchema = MAIN_DATA.UI
local helpWidget = HELP_DATA.WIDGET

local currentSettings = App.getSettings()
local currentFilter = App.getCategoryFilter()

--GRID TEXTS
local currentLibrary = mainGui.Main.CurrentLibrary
local mainText = currentLibrary.GridMainText
local subText = currentLibrary.GridSubText

--SETTINGS
local settingsFrame = currentLibrary.SettingsFrame
local settingsSwitches = settingsFrame.Switches
local showInstanceColButton = settingsSwitches.showInstanceColors.SwitchFrame.ButtonDot
local alignToNormalButton = settingsSwitches.AlignToNormal.SwitchFrame.ButtonDot
local sortByNameButton = settingsSwitches.SortBy.byNameButton
local sortByInstanceButton = settingsSwitches.SortBy.byInstanceButton
local autoAnchorButton = settingsSwitches.AutoAnchor.SwitchFrame.ButtonDot

--LEFT ELEMENTS
local LeftSegment = mainGui.Main.TopBar.LeftSegment
local searchBox = LeftSegment.SearchBar.SearchBox
local searchBarImage = LeftSegment.SearchBar.Image

local allButton = LeftSegment.SortAllButton
local modelsButton = LeftSegment.SortModelsButton
local meshesButton = LeftSegment.SortMeshesButton
local audioButton = LeftSegment.SortAudioButton
local imagesButton = LeftSegment.SortImagesButton
local topBarButtons = {
	["All"] = allButton,
	["Models"] = modelsButton,
	["Meshes"] = meshesButton,
	["Audio"] = audioButton,
	["Images"] = imagesButton
}

--RIGHT ELEMENTS
local RightSegment = mainGui.Main.TopBar.RightSegment
local settingsButton = RightSegment.SettingsFrame.ImageButton
local helpButton = RightSegment.HelpFrame.ImageButton
local slider = RightSegment.Slider
local sliderTrigger = slider.Trigger

--OTHER
local debounce = false
local settingsOpened = false

local isSliderActive = false
local inputUpdateConn
local inputReleaseConn

-----------------------------
-- CONSTANTS --
-----------------------------
local ERRORS = {
	["NoLibraries"] = {"Import assets to get started", "Add sources to your library."},
	["NoSelection"] = {"Select a library", "Choose a library to view its assets."},
	["NoMatches"] = {"No matching items", "Try adjusting your filters."},
	["EmptyFolder"] = {"This folder is empty", "Import assets to show them here."},
	["None"] = {"",""},
	["TEMP"] = {"Toolbox is work in progress", "Check back here in the upcoming "}
}

local SETTING_INFO = TweenInfo.new(.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local REFRESH_INFO = TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function toggleSettings()
	if debounce then return end
	debounce = true
	
	TS:Create(settingsButton, REFRESH_INFO, {Rotation = 180}):Play()
	
	if settingsOpened then
		TS:Create(settingsFrame, SETTING_INFO, {Position = UDim2.fromScale(1.31, 0)}):Play()
		settingsButton:AddTag("Secondary")
	else
		TS:Create(settingsFrame, SETTING_INFO, {Position = UDim2.fromScale(1, 0)}):Play()
		settingsButton:RemoveTag("Secondary")
	end
	
	task.wait(.6)
	
	settingsButton.Rotation = -180
	debounce = false
	settingsOpened = not settingsOpened
end

local function setSwitchState(switchFrame:Frame, state:boolean)
	if switchFrame:FindFirstChild("ButtonDot") == nil then return end
	if state then
		switchFrame:AddTag("Accent")
		TS:Create(switchFrame.ButtonDot, SETTING_INFO, {Position = UDim2.fromScale(.5, 0)}):Play()
	else
		switchFrame:RemoveTag("Accent")
		TS:Create(switchFrame.ButtonDot, SETTING_INFO, {Position = UDim2.fromScale(0, 0)}):Play()
	end
end

local function toggleSwitch(switchFrame:Frame)
	if debounce or switchFrame:FindFirstChild("ButtonDot") == nil then return end
	debounce = true
	
	local attrib = switchFrame:GetAttribute("SETTING_NAME")
	if not attrib then
		warn("AssetVault - Failed to find attribute 'SETTING_NAME' in switchFrame, add it.")
	end
	
	local newState = not currentSettings[attrib]
	
	setSwitchState(switchFrame, newState)
	
	currentSettings[attrib] = newState
	
	App.setSettings(currentSettings)
	
	task.wait(.35)
	debounce = false
end

local function setSortMethod(method, init)
	init = init or false
	if method == "Name" then
		sortByNameButton:AddTag("Accent")
		sortByNameButton:AddTag("Bold")
		sortByInstanceButton:RemoveTag("Accent")
		sortByInstanceButton:RemoveTag("Bold")
	elseif method == "Instance" then
		sortByInstanceButton:AddTag("Accent")
		sortByInstanceButton:AddTag("Bold")
		sortByNameButton:RemoveTag("Accent")
		sortByNameButton:RemoveTag("Bold")
	else
		warn("What method is this? Report this to discord")
		return
	end
	if not init then App.setSortBy(method) end
end

local function updateSelectedTopBarButton(button:TextButton)
	local category
	for cat, but in topBarButtons do
		if but == button then
			category = cat
			but:AddTag("Accent")
			but:RemoveTag("Secondary")
		else
			but:AddTag("Secondary")
			but:RemoveTag("Accent")
		end
	end
	if category then
		currentFilter = category
		App.setCategoryFilter(category)
	end
end
-----------------------------
-- MAIN --
-----------------------------
local function onInit()
	local libs = Tree.getLibraries() or {}
	libs["FAVORITES"] = nil
	libs["RECENT"] = nil
	libs["TOOLBOX"] = nil
	
	local source = App.getSource()
	if not (libs and next(libs)) then --No libraries
		mainText.Text = ERRORS.NoLibraries[1]
		subText.Text = ERRORS.NoLibraries[2]
	elseif source == "None" then --No library chosen
		mainText.Text = ERRORS.NoSelection[1]
		subText.Text = ERRORS.NoSelection[2]
	end
	
end

local function init()
	onInit()
	setSwitchState(settingsSwitches.showInstanceColors.SwitchFrame, currentSettings.ShowInstanceColors)
	setSwitchState(settingsSwitches.AlignToNormal.SwitchFrame, currentSettings.AlignToNormal)
	setSwitchState(settingsSwitches.AutoAnchor.SwitchFrame, currentSettings.AutoAnchor)
	setSortMethod(App.getSortBy(), true)
	updateSelectedTopBarButton(topBarButtons[currentFilter])
	
	slider.Full.Size = UDim2.new(App.getGridSize(), 0, .2, 0)
end

local function onGridTextUpdate(txtType)
	assert(type(txtType) == "string")
	if ERRORS[txtType] then
		mainText.Text = ERRORS[txtType][1]
		subText.Text = ERRORS[txtType][2]
	elseif txtType == "INIT" then
		onInit()
	else
		mainText.Text = "Unknown text type"
		subText.Text = txtType
	end
end

local function onSearchBoxUpdate(enterPressed)
	if not enterPressed then
		searchBarImage:AddTag("SecondaryText")
		return 
	end
	local rawText = searchBox.Text
	
	local cleanText = string.gsub(rawText, "[;,'\"~`]", "")
	
	searchBox.Text = cleanText
	App.setSearchQuery(cleanText)
end


--Sliders
local function updateSlider(position)
	
	print("MouseX",position.X)
	local output = (position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X
	output = math.clamp(output, 0, 1)
	
	local cleaned = math.round(output * 100) / 100
	
	App.setGridSize(cleaned)

	slider.Full.Size = UDim2.new(output, 0, .2, 0)
end

function deactiveSlider(position)
	isSliderActive = false

	if inputUpdateConn then
		inputUpdateConn:Disconnect()
		inputUpdateConn = nil
	end
	if inputReleaseConn then
		inputReleaseConn:Disconnect()
		inputReleaseConn = nil
	end
end

function activateSlider()
	isSliderActive = true
	
	inputUpdateConn = sliderTrigger.InputChanged:Connect(function(moveInput)
		if not isSliderActive or moveInput.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		while isSliderActive do
			updateSlider(moveInput.Position)
			task.wait()
		end
	end)
	
	inputReleaseConn = sliderTrigger.InputEnded:Connect(function(releaseInput)
		if releaseInput.UserInputType == Enum.UserInputType.MouseButton1 then
			deactiveSlider()
		end
	end)
end



init()

-----------------------------
-- CONNECTIONS --
-----------------------------
Signals.updateGridTexts:Connect(onGridTextUpdate)
Signals.settingsChanged:Connect(function(newSettings)
	currentSettings = newSettings
end)

showInstanceColButton.Activated:Connect(function() toggleSwitch(settingsSwitches.showInstanceColors.SwitchFrame) end)
alignToNormalButton.Activated:Connect(function() toggleSwitch(settingsSwitches.AlignToNormal.SwitchFrame) end)
autoAnchorButton.Activated:Connect(function() toggleSwitch(settingsSwitches.AutoAnchor.SwitchFrame) end)
sortByNameButton.Activated:Connect(function() setSortMethod("Name") end)
sortByInstanceButton.Activated:Connect(function() setSortMethod("Instance") end)

settingsButton.Activated:Connect(toggleSettings)
helpButton.Activated:Connect(function()
	helpWidget.Enabled = not helpWidget.Enabled
end)

searchBox.FocusLost:Connect(onSearchBoxUpdate)
searchBox.Focused:Connect(function()
	if #searchBox.Text > 0 then
		searchBarImage:RemoveTag("SecondaryText")
	end
end)
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	if #searchBox.Text == 0 then
		searchBarImage:AddTag("SecondaryText")
	else
		searchBarImage:RemoveTag("SecondaryText")
	end
end)

allButton.Activated:Connect(function() updateSelectedTopBarButton(allButton) end)
modelsButton.Activated:Connect(function() updateSelectedTopBarButton(modelsButton) end)
meshesButton.Activated:Connect(function() updateSelectedTopBarButton(meshesButton) end)
audioButton.Activated:Connect(function() updateSelectedTopBarButton(audioButton) end)
imagesButton.Activated:Connect(function() updateSelectedTopBarButton(imagesButton) end)

sliderTrigger.MouseButton1Down:Connect(activateSlider)

return Bar
