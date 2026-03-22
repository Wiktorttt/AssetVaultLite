local Signal = require(script.Parent.Parent.Parent.Utils.Signal)

return {
	["libraryTreeChanged"] = Signal(), --string
	["sourceChanged"] = Signal(), --string
	["categoryChanged"] = Signal(), --string
	["searchChanged"] = Signal(), --string
	["sortByChanged"] = Signal(), --string
	["sortTypeChanged"] = Signal(), --string
	["gridSizeChanged"] = Signal(), -- float 0.01 to 1
	["settingsChanged"] = Signal(), --array of settings
	["folderToggled"] = Signal(), -- UUID, boolean
	["selectedLibraryChanged"] = Signal(), --UUID
	["onPluginUnloading"] = Signal(),
	["updateGridTexts"] = Signal(),
	["refreshClicked"] = Signal(),
	["resetInitialized"] = Signal()

}