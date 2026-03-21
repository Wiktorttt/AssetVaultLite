-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local App = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules
local ASSETS = env.Assets

-----------------------------
-- SERVICES --
-----------------------------
local HTTP = game:GetService("HttpService")
local Collection = game:GetService("CollectionService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Signals = require(MODULES.API.Signals)
local Vault = require(MODULES.Core.VaultData)
local Pathfinder = require(MODULES.UI.Pathfinder)

-----------------------------
-- VARIABLES --
-----------------------------
local pluginIns : Plugin = nil

local userSettings = {}
local currentInstances = {}

-----------------------------
-- CONSTANTS --
-----------------------------
local defaultSettings = {
	["CurrentSource"] = "None",
	["CurrentCategoryFilter"] = "All",
	["SearchQuery"] = "",
	["SortType"] = "Grid",
	["SortBy"] = "Name",
	["ShowInstanceColors"] = false,
	["AlignToNormal"] = true,
	["AutoAnchor"] = true,
	["GridSize"] = .5,
	["InstantSearch"] = false
}

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function checkIfSourceStillValid(fullData)
	local found = false
	for _, data in fullData do
		if data.UUID == userSettings.CurrentSource then
			found = true
			break
		end 
	end
	if not found then
		App.setSource("None")
	end
	currentInstances = fullData
end

local function reconcile(target)
	for k, v in pairs(defaultSettings) do
		if target[k] == nil then
			target[k] = v
		elseif type(target[k]) == "table" and type(v) == "table" then
			reconcile(target[k], v)
		end
	end
	return target
end

local function getInstanceBySource(source)
	for _, instance in currentInstances do
		if instance.UUID == source then
			return instance.Instance
		end
	end
end
-----------------------------
-- SETTERS --
-----------------------------
function App.setSource(newUUID)
	if userSettings.CurrentSource == newUUID then return end
	assert(type(newUUID) == "string", "Not valid UUID as source")
	userSettings.CurrentSource = newUUID
	Signals.sourceChanged:Fire(newUUID)
end

function App.setCategoryFilter(category)
	if userSettings.CurrentCategoryFilter == category then return end
	assert(type(category) == "string")
	userSettings.CurrentCategoryFilter = category
	Signals.categoryChanged:Fire(category)
end

function App.setSearchQuery(text)
	if userSettings.SearchQuery == text then return end
	assert(type(text) == "string")
	userSettings.SearchQuery = text
	Signals.searchChanged:Fire(text)
end
function App.setSortBy(text)
	if userSettings.SortBy == text then return end
	assert(type(text) == "string")
	userSettings.SortBy = text
	Signals.sortByChanged:Fire(text)
end
function App.setSortType(sortType)
	if userSettings.SortType == sortType then return end
	assert(type(sortType) == "string")
	userSettings.SortType = sortType
	Signals.sortTypeChanged:Fire(sortType)
end
function App.setGridSize(percentage)
	if userSettings.GridSize == percentage then return end
	assert(type(percentage) == "number")
	userSettings.GridSize = percentage
	Signals.gridSizeChanged:Fire(percentage)
end
function App.setSettings(array)
	local changed = false
	assert(type(array) == "table")
	if array.ShowInstanceColors ~= nil then
		userSettings.ShowInstanceColors = array.ShowInstanceColors
		changed = true
	end
	if array.AlignToNormal ~= nil then
		userSettings.AlignToNormal = array.AlignToNormal
		changed = true
	end
	if array.AutoAnchor ~= nil then
		userSettings.AutoAnchor = array.AutoAnchor
		changed = true
	end
	if array.InstantSearch ~= nil then
		userSettings.InstantSearch = array.InstantSearch
		changed = true
	end
	if changed then
		Signals.settingsChanged:Fire(array)
		App.saveData()
	end
end

-----------------------------
-- GETTERS --
-----------------------------
function App.getSource(): (string, Instance?)
	local instance = getInstanceBySource(userSettings.CurrentSource)
	if instance then
		return userSettings.CurrentSource, instance
	else
		return userSettings.CurrentSource
	end
end

function App.getInstanceByUUID(uuid:string): Instance
	return getInstanceBySource(uuid)
end

function App.getCategoryFilter(): string
	return userSettings.CurrentCategoryFilter
end

function App.getSearchQuery(): string
	return userSettings.SearchQuery
end

function App.getSortBy(): string
	return userSettings.SortBy
end

function App.getSortType(): string
	return userSettings.SortType
end

function App.getGridSize() : number
	return userSettings.GridSize
end

function App.getSettings()
	local array = {
		["ShowInstanceColors"] = userSettings.ShowInstanceColors,
		["AlignToNormal"] = userSettings.AlignToNormal,
		["AutoAnchor"] = userSettings.AutoAnchor,
		["InstantSearch"] = userSettings.InstantSearch
	}

	if array.ShowInstanceColors == nil then array.ShowInstanceColors = defaultSettings.ShowInstanceColors end
	if array.AlignToNormal == nil then array.AlignToNormal = defaultSettings.AlignToNormal end
	if array.AutoAnchor == nil then array.AutoAnchor = defaultSettings.AutoAnchor end
	if array.InstantSearch == nil then array.InstantSearch = defaultSettings.InstantSearch end

	return array
end

-----------------------------
-- SAVING / LOADING --
-----------------------------
function App.init(instance)
	pluginIns = instance
end

function App.saveData()
	if not pluginIns then
		warn(`>| AssetVault {env.Config:GetAttribute("version")} not initalized. Report the bug to discord. Data will not be saved.`)
		return
	end
	
	Vault.save()
	pluginIns:SetSetting("userSettings", userSettings)
end

function App.loadData()
	local savedData = pluginIns:GetSetting("userSettings")
	local activeSettings = table.clone(defaultSettings)

	if savedData and type(savedData) == "table" then
		activeSettings = reconcile(savedData)
		
	else
		warn("AssetVault: Saved data was corrupt or empty. Defaults loaded.")
	end
	
	userSettings = activeSettings
	
	Vault.load()
	
	App.setSource(activeSettings.CurrentSource)
	App.setCategoryFilter(activeSettings.CurrentCategoryFilter)
	App.setSearchQuery(activeSettings.SearchQuery)
	App.setSortType(activeSettings.SortType)
	App.setGridSize(activeSettings.GridSize)
end

local function onPluginUnloading()
	userSettings.CurrentSource = "None"
	App.saveData()
end

-----------------------------
-- CONNECTIONS --
-----------------------------
Signals.selectedLibraryChanged:Connect(App.setSource)
Signals.libraryTreeChanged:Connect(checkIfSourceStillValid)
Signals.onPluginUnloading:Connect(onPluginUnloading)
return App
