-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local Grid = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets
type importSchema = typeof(ASSETS.AV_Import)
-----------------------------
-- SERVICES --
-----------------------------
local selectionService = game:GetService("Selection")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Pathfinder = require(MODULES.UI.Pathfinder)
local Signals = require(MODULES.API.Signals)
local App = require(MODULES.Core.AppState)
local Vault = require(MODULES.Core.VaultData)
local isInstanceValidForLibrary = require(UTILS.isInstanceValidForLibrary)
-----------------------------
-- VARIABLES --
-----------------------------
local IMPORT_DATA = Pathfinder:get("IMPORT")
local importUI : importSchema = IMPORT_DATA.UI
local importWidget : DockWidgetPluginGui? = IMPORT_DATA.WIDGET

local debounce = false
-----------------------------
-- CONSTANTS --
-----------------------------
local count = importUI.ImportFrame.SelectedCount
local names = importUI.ImportFrame.SelectedNames
local importButton = importUI.ImportFrame.ImportButton

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function checkIfAllFolders(instances)
	for _, instance in ipairs(instances) do
		if not instance:IsA("Folder") then return false end
	end
	return true
end

-----------------------------
-- MAIN --
-----------------------------
local function onImportButtonClicked()
	if debounce then return end
	debounce = true
	
	if #Vault.rootUUIDs >= 1 then
		warn(">| AssetVault Lite: Folder limit hit. Buy Pro version on itch.io to add more folders.")
		task.delay(.5, function() debounce = false end)
		return
	end
	
	local raw = selectionService:Get()
	if #raw == 0 then
		task.delay(1, function()
			debounce = false
		end)
		return
	end
	
	local firstFiltered = nil
	for _, rawIns in raw do
		if isInstanceValidForLibrary.x(rawIns) then
			firstFiltered = rawIns
			break
		end
	end
	
	if firstFiltered then
		importWidget.Enabled = not importWidget.Enabled
		Vault.appendLibraries({firstFiltered})
		if App.getSource() == "None" then
			Signals.updateGridTexts:Fire("NoSelection")
		end
	end
	task.delay(.5, function()
		debounce = false
	end)
end

local function onSelectionChange()
	local instancesArray = selectionService:Get()
	count.Text = `Selected: {#instancesArray}`
	
	local insNames = {}
	for _, instance in instancesArray do
		table.insert(insNames, instance.Name)
	end
	local text
	if #insNames > 0 then
		text = "Instances: "..table.concat(insNames, ", ")
		if #text > 38 then
			text = string.sub(text, 1, 38).."..."
		end
	else
		text = "Instances: None"
	end
	names.Text = text
	
	local isAnyIncorrect = false
	local folders = 0
	for _, ins in ipairs(instancesArray) do
		if not ins:IsA("Folder") then
			isAnyIncorrect = true
		else folders += 1 end
	end
	
	if #Vault.rootUUIDs >= 1 then
		importButton.Text = "Limit reached (Lite Version Cap)"
	elseif folders > 0 then
		importButton.Text = "Import 1 folder (Lite Version Cap)"
	else
		importButton.Text = "Import 0 folders"
	end
	
	importUI.ImportFrame.Warning.Visible = isAnyIncorrect
end
-----------------------------
-- CONNECTIONS --
-----------------------------
importButton.Activated:Connect(onImportButtonClicked)
local conn = selectionService.SelectionChanged:Connect(onSelectionChange)

Signals.libraryTreeChanged:Connect(onSelectionChange)

Signals.onPluginUnloading:Connect(function()
	if conn then conn:Disconnect() end
end)

return Grid
