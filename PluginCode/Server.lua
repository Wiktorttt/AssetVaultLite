-- // Copyright 2026, wiktorttt, All rights reserved by wiktorttt.
-- ===============================================================
local env = script.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Signals = require(MODULES.API.Signals)
local Pathfinder = require(MODULES.UI.Pathfinder)

-----------------------------
-- CONSTANTS --
-----------------------------
local PLUGIN_LOGO = "rbxassetid://112022833503238"
local STUDIO_THEME = settings().Studio.Theme

local MAIN_INFO = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Bottom,
	false,
	false,
	1000, 300, 700, 200
)

local IMPORT_INFO = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	true,
	300, 400, 300, 400
)

local HELP_INFO = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	true,
	500, 400, 400, 320
)

local ADDITIONAL_INFO = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	true,
	600, 400, 300, 200
)

-----------------------------
-- VARIABLES --
-----------------------------
local toolbar = plugin:CreateToolbar("AssetVaultLite")
local button = toolbar:CreateButton("Asset Vault Lite", "Open Asset Vault Lite Plugin", PLUGIN_LOGO)
local mainWidget = plugin:CreateDockWidgetPluginGuiAsync("AssetVaultLite_MAIN", MAIN_INFO)
local importWidget = plugin:CreateDockWidgetPluginGuiAsync("AssetVaultLite_IMPORT", IMPORT_INFO)
local helpWidget = plugin:CreateDockWidgetPluginGuiAsync("AssetVaultLite_HELP", HELP_INFO)
local settingsWidget = plugin:CreateDockWidgetPluginGuiAsync("AssetVaultLite_SETTINGS", ADDITIONAL_INFO)

local dataLoaded = false
local dataChanged = false

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function onThemeChange()
	STUDIO_THEME = settings().Studio.Theme
	if STUDIO_THEME.Name == "Light" then
		env.Themes.PluginStyleSheet:SetDerives({env.Themes.BaseStyleSheet, env.Themes.PluginThemes.Light})
	else
		env.Themes.PluginStyleSheet:SetDerives({env.Themes.BaseStyleSheet, env.Themes.PluginThemes.Dark})
	end
end

-----------------------------
-- INIT --
-----------------------------
mainWidget.Title = `Asset Vault Lite {env.Config:GetAttribute("version")}`
importWidget.Title = `Import into Asset Vault Lite`
helpWidget.Title = `Asset Vault FAQ Section`
settingsWidget.Title = `Asset Vault Lite Internal Settings`

local mainGui = ASSETS.AV_Main:Clone()
local importGui = ASSETS.AV_Import:Clone()
local helpGui = ASSETS.AV_Help:Clone()
local settingsGui = ASSETS.AV_AdditionalSettings:Clone()

mainGui.Parent = mainWidget
importGui.Parent = importWidget
helpGui.Parent = helpWidget
settingsGui.Parent = settingsWidget
ASSETS.StyleLink:Clone().Parent = mainWidget
ASSETS.StyleLink:Clone().Parent = importWidget
ASSETS.StyleLink:Clone().Parent = helpWidget
ASSETS.StyleLink:Clone().Parent = settingsWidget

Pathfinder:registerData{
	["MAIN"] = {["UI"] = mainGui, ["WIDGET"] = mainWidget},
	["IMPORT"] = {["UI"] = importGui, ["WIDGET"] = importWidget},
	["HELP"] = {["UI"] = helpGui, ["WIDGET"] = helpWidget},
	["SETTINGS"] = {["UI"] = settingsGui, ["WIDGET"] = settingsWidget}
}
----------------------------------
local AppState = require(MODULES.Core.AppState)
local Vault = require(MODULES.Core.VaultData)
local Dragger = require(MODULES.UI.Dragger)

AppState.init(plugin)
Vault.init(plugin)

AppState.loadData()

for _, module in MODULES.Components:GetChildren() do
	require(module)
end

Dragger.init(plugin)
----------------------------------

settings().Studio.ThemeChanged:Connect(onThemeChange)
onThemeChange()

-----------------------------
-- MAIN --
-----------------------------
local function onLaunchClicked()
	mainWidget.Enabled = not mainWidget.Enabled
	if not dataLoaded or dataChanged then
		AppState.loadData()
		Signals.updateGridTexts:Fire("INIT")
		dataLoaded = true
		dataChanged = false
	end
	
end

local function saveOnClose()
	if importWidget.Enabled then importWidget.Enabled = false end
	AppState.saveData()
	dataChanged = true
end

-----------------------------
-- INIT --
-----------------------------
onLaunchClicked()

-----------------------------
-- CONNECTIONS --
-----------------------------
button.Click:Connect(onLaunchClicked)
mainWidget:BindToClose(saveOnClose)
plugin.Unloading:Connect(function()
	Signals.onPluginUnloading:Fire()
end)