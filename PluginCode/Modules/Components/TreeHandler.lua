-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local Tree = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets
type mainSchema = typeof(ASSETS.AV_Main)

-----------------------------
-- SERVICES --
-----------------------------
local CollectionService = game:GetService("CollectionService")
local TS = game:GetService("TweenService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Signals = require(MODULES.API.Signals)
local Pathfinder = require(MODULES.UI.Pathfinder)
local Vault = require(MODULES.Core.VaultData)
local App = require(MODULES.Core.AppState)

-----------------------------
-- VARIABLES --
-----------------------------
local previousUUIDSelected = nil

local MAIN_DATA = Pathfinder:get("MAIN")
local IMPORT_DATA = Pathfinder:get("IMPORT")
local SETTINGS_DATA = Pathfinder:get("SETTINGS")
local mainGui : mainSchema = MAIN_DATA.UI
local importWidget : DockWidgetPluginGui? = IMPORT_DATA.WIDGET
local settingsWidget : DockWidgetPluginGui? = SETTINGS_DATA.WIDGET

local LIBRARIES = mainGui.Libraries
local addSourceButton = LIBRARIES.Sources.addSourcesFrame.ImageButton
local refreshButton = LIBRARIES.Sources.refreshFrame.ImageButton
local wrenchButton = LIBRARIES.Sources.fixFrame.ImageButton
local SCROLL_LIST = LIBRARIES.SourcesScroll

local Favorites = SCROLL_LIST.Favorites
local Recent = SCROLL_LIST.Recent
local Toolbox = SCROLL_LIST.Toolbox

local NODE = ASSETS.CustomNode

local createdNodesMap = {}

-----------------------------
-- CONSTANTS --
-----------------------------
local SUBFOLDER = "rbxassetid://79919038320501"
--local MAINFOLDER = "rbxassetid://101984736504042"
local REFRESH_INFO = TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function changeLibrary(UUID)
	Signals.selectedLibraryChanged:Fire(UUID)
end

local function clearTree()
	for _, obj in SCROLL_LIST:GetChildren() do
		if obj.Name == "CustomNode" and obj:IsA("Frame") then
			obj:Destroy()
		end
	end
	createdNodesMap = {
		["FAVORITES"] = Favorites,
		["RECENT"] = Recent,
		["TOOLBOX"] = Toolbox
	}
end


local function getSortedData(fullData)
	local sorted = table.clone(fullData)
	table.sort(sorted, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	return sorted
end

-----------------------------
-- MAIN --
-----------------------------
local function onPluginUnloading()
	local objs = CollectionService:GetTagged("LibSelected")
	if #objs == 0 then return end
	for _, obj in objs do
		obj:RemoveTag("LibSelected")
	end
	
	previousUUIDSelected = nil
end

local function createNewNode(data, currentSource)
	local new = NODE:Clone()
	local arrow = new.Header.Arrow
	local instance = App.getInstanceByUUID(data.UUID)
	local hoverTrigger = nil
	
	new:AddTag(data.UUID)
	arrow.ImageTransparency = 1
	
	new.Header.FolderName.Text = data.Name
	new.Parent = SCROLL_LIST
	
	new.Header.FolderName.Activated:Connect(function()
		changeLibrary(data.UUID)
	end)
	
	if data.UUID == currentSource then
		new.Header:AddTag("LibSelected")
	end
	
	new.Header.FolderName.MouseEnter:Connect(function()
		hoverTrigger = task.delay(1, function()
			new.Header.FolderName.Text = instance and instance:GetFullName() or "Error"
			new.Header.FolderName.TextScaled = true
		end)
	end)

	new.Header.FolderName.MouseLeave:Connect(function()
		if hoverTrigger then
			task.cancel(hoverTrigger)
			hoverTrigger = nil
		end
		new.Header.FolderName.Text = data.Name
		new.Header.FolderName.TextScaled = false
	end)
	
	return new
end


local function populateTree(fullData)
	clearTree()
	local sortedData = getSortedData(fullData)
	local currentSource = App.getSource()
	
	for i, data in sortedData do
		local node : Frame = createNewNode(data, currentSource)
		node.LayoutOrder = i
		createdNodesMap[data.UUID] = node
	end
end

local function switchSelectLibrary(UUID)
	if previousUUIDSelected and previousUUIDSelected == UUID then return end

	if previousUUIDSelected then
		local oldFrame = createdNodesMap[previousUUIDSelected]
		if oldFrame then oldFrame.Header:RemoveTag("LibSelected") end
	end
	
	local frame = createdNodesMap[UUID]
	if not frame then return end
	
	frame.Header:AddTag("LibSelected")
	previousUUIDSelected = UUID
end

function Tree.getLibraries()
	return table.clone(createdNodesMap)
end

-----------------------------
-- CONNECTIONS --
-----------------------------
Signals.selectedLibraryChanged:Connect(switchSelectLibrary)
Signals.libraryTreeChanged:Connect(populateTree)
Signals.onPluginUnloading:Connect(onPluginUnloading)

-------------------------------------------
local d = false
local sourceThread = nil
addSourceButton.Activated:Connect(function()
	if d then return end
	d = true
	importWidget.Enabled = not importWidget.Enabled
	task.wait(.5)
	d = false
end)
addSourceButton.Parent.MouseEnter:Connect(function()
	sourceThread = task.delay(.3, function()
		addSourceButton.Parent.moreInfo.Visible = true
	end)
end)
addSourceButton.Parent.MouseLeave:Connect(function()
	if sourceThread then
		task.cancel(sourceThread)
		sourceThread = nil
	end
	addSourceButton.Parent.moreInfo.Visible = false
end)
-------------------------------------------
local refreshThread = nil
refreshButton.Activated:Connect(function()
	if d then return end
	d = true
	TS:Create(refreshButton.Parent.refreshImage, REFRESH_INFO, {Rotation = 180}):Play()
	Signals.libraryTreeChanged:Fire(Vault.getLibrariesWithChildren())
	Signals.refreshClicked:Fire()
	task.wait(.7)
	refreshButton.Parent.refreshImage.Rotation = -180
	d = false
end)
refreshButton.Parent.MouseEnter:Connect(function()
	refreshThread = task.delay(.3, function()
		refreshButton.Parent.moreInfo.Visible = true
	end)
end)
refreshButton.Parent.MouseLeave:Connect(function()
	if refreshThread then
		task.cancel(refreshThread)
		refreshThread = nil
	end
	refreshButton.Parent.moreInfo.Visible = false
end)
-------------------------------------------
local fixesThread = nil
wrenchButton.Activated:Connect(function()
	if d then return end
	d = true
	
	settingsWidget.Enabled = not settingsWidget.Enabled
	task.wait(.5)

	d = false
end)
wrenchButton.Parent.MouseEnter:Connect(function()
	fixesThread = task.delay(.3, function()
		wrenchButton.Parent.moreInfo.Visible = true
	end)
end)
wrenchButton.Parent.MouseLeave:Connect(function()
	if fixesThread then
		task.cancel(fixesThread)
		fixesThread = nil
	end
	wrenchButton.Parent.moreInfo.Visible = false
end)

-------------------------------------------
Favorites.Header.FolderName.Activated:Connect(function() changeLibrary("FAVORITES") end)
Recent.Header.FolderName.Activated:Connect(function() changeLibrary("RECENT") end)
Toolbox.Header.FolderName.Activated:Connect(function() changeLibrary("TOOLBOX") end)

Signals.resetInitialized:Connect(clearTree)

return Tree
