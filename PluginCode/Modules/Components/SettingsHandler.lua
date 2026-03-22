-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local Sets = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets
type addSchema = typeof(ASSETS.AV_AdditionalSettings)
-----------------------------
-- SERVICES --
-----------------------------
local Collection = game:GetService("CollectionService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Pathfinder = require(MODULES.UI.Pathfinder)
local App = require(MODULES.Core.AppState)
local Signals = require(MODULES.API.Signals)

-----------------------------
-- VARIABLES --
-----------------------------
local SETTINGS_DATA = Pathfinder:get("SETTINGS")
local MAIN_DATA = Pathfinder:get("MAIN")

local settingsUI : addSchema = SETTINGS_DATA.UI
local settingsWidget : DockWidgetPluginGui? = SETTINGS_DATA.WIDGET
local mainWidget : DockWidgetPluginGui? = MAIN_DATA.WIDGET

local SCROLL_FRAME = settingsUI.Scroll

local eraseUserDataButton = SCROLL_FRAME.eraseData.settingButton
local eraseTagsButton = SCROLL_FRAME.cleanup.settingButton

local debounce = false

-----------------------------
-- MAIN --
-----------------------------
local function onEraseUserDataClick()
	if debounce then return end
	debounce = true

	App.setSource("None")
	App.setCategoryFilter(App.defaultSettings.CurrentCategoryFilter)
	App.setSearchQuery("")
	App.setSortBy(App.defaultSettings.SortBy)
	App.setSortType(App.defaultSettings.SortType)
	App.setGridSize(App.defaultSettings.GridSize)
	App.setSettings{
		["ShowInstanceColors"] = App.defaultSettings.ShowInstanceColors,
		["AlignToNormal"] = App.defaultSettings.AlignToNormal,
		["AutoAnchor"] = App.defaultSettings.AutoAnchor,
		["InstantSearch"] = App.defaultSettings.InstantSearch
	}

	local Vaults = Collection:GetTagged("VaultRoot")
	for _, vault in Vaults do
		for _, favorited in vault:QueryDescendants(".AV_FAVORITED") do
			favorited:RemoveTag("AV_FAVORITED")
		end
	end

	warn(`>= Asset Vault {env.Config:GetAttribute("version")}: User data erased successfully`)
	
	Signals.resetInitialized:Fire()

	mainWidget.Enabled = false
	settingsWidget.Enabled = false
	
	task.wait(.5)
	debounce = false
end

local function onCleanupAssetTagsClick()
	if debounce then return end
	debounce = true

	local Vaults = Collection:GetTagged("VaultRoot")
	for _, vault in Vaults do
		vault:RemoveTag("VaultRoot")
		vault:SetAttribute("VaultUUID", nil)
		for _, favorited in vault:QueryDescendants(".AV_FAVORITED") do
			favorited:RemoveTag("AV_FAVORITED")
		end
		for _, folder in vault:QueryDescendants("Folder") do
			folder:SetAttribute("VaultUUID", nil)
		end
	end

	warn(`>= Asset Vault {env.Config:GetAttribute("version")}: AV Tags erased successfully`)
	
	mainWidget.Enabled = false
	settingsWidget.Enabled = false
	
	task.wait(.5)
	debounce = false
end

-----------------------------
-- CONNECTIONS --
-----------------------------
eraseUserDataButton.Activated:Connect(onEraseUserDataClick)
eraseTagsButton.Activated:Connect(onCleanupAssetTagsClick)

return Sets