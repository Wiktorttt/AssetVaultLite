-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local Grid = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets
type mainSchema = typeof(ASSETS.AV_Main)

-----------------------------
-- SERVICES --
-----------------------------
local CollectionService = game:GetService("CollectionService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Pathfinder = require(MODULES.UI.Pathfinder)
local App = require(MODULES.Core.AppState)
local Signals = require(MODULES.API.Signals)
local Dragger = require(MODULES.UI.Dragger)
local Vault = require(MODULES.Core.VaultData)

-----------------------------
-- VARIABLES --
-----------------------------
local MAIN_DATA = Pathfinder:get("MAIN")
local IMPORT_DATA = Pathfinder:get("IMPORT")
local mainGui : mainSchema = MAIN_DATA.UI
local currentLibrary = mainGui.Main.CurrentLibrary

local GRID_SCROLL = currentLibrary.Grid

local GRID_FRAME = ASSETS.ObjectFrame

local GRID_LAYOUT = GRID_SCROLL.UIGridLayout

local assetCounterText = currentLibrary.ItemsCountFrame.TextLabel

local currentSearchQuery = nil
local currentFilter = nil
local currentSettings = nil

local clickStartPos = nil
local isClicking = false

-----------------------------
-- CONSTANTS --
-----------------------------
local CLASS_PRIORITY = {
	MeshPart = 1,
	Model = 2,
	Part = 3,
	WedgePart = 3,
	CornerWedgePart = 3,
	TrussPart = 3,
	SurfaceAppearance = 4,
	Decal = 5,
	Texture = 6,
	Sound = 7
}
local DEFAULT_PRIORITY = 99 -- Assign a high number for classes not explicitly listed

local CLASS_COLORS = {
	MeshPart = Color3.fromRGB(255, 99, 180),
	Model = Color3.fromRGB(255, 215, 0),
	Part = Color3.fromRGB(130, 220, 130),
	WedgePart = Color3.fromRGB(130, 220, 130),
	CornerWedgePart = Color3.fromRGB(130, 220, 130),
	TrussPart = Color3.fromRGB(130, 220, 130),
	SurfaceAppearance = Color3.fromRGB(170, 130, 255),
	Decal = Color3.fromRGB(255, 150, 80),
	Texture = Color3.fromRGB(255, 150, 80),
	Sound = Color3.fromRGB(255, 100, 100),
	DEFAULT = Color3.fromRGB(255, 255, 255)
}

local MAX_GRID_HEIGHT = 216
local MAX_GRID_WIDTH = 180
local MIN_GRID_HEIGHT = 90
local MIN_GRID_WIDTH = 75

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function cleanupGrid()
	for _, object in GRID_SCROLL:GetChildren() do
		if object:IsA("Frame") then object:Destroy() end
	end
end

local function truncateText(str)
	if #str > 16 then
		str = string.gsub(str, "-", " ")
		str = string.gsub(str, "_", " ")
		str = string.sub(str, 1, 13).."..."
	end
	
	return str
end

local function sortChildrenByInstance(children)
	table.sort(children, function(a, b)
		local priorityA = CLASS_PRIORITY[a.ClassName] or DEFAULT_PRIORITY
		local priorityB = CLASS_PRIORITY[b.ClassName] or DEFAULT_PRIORITY

		if priorityA == priorityB then
			return a.Name:lower() < b.Name:lower()
		end

		return priorityA < priorityB
	end)

	return children
end

local function updateSelectionOnObjectClick(objFrame:Frame, inputObj:InputObject, shouldAdd:boolean)
	if shouldAdd then
		objFrame:AddTag("ObjSelected")
	else
		objFrame:RemoveTag("ObjSelected")
	end
	if inputObj:IsModifierKeyDown(Enum.ModifierKey.Ctrl) then return end
	for _, child in GRID_SCROLL:GetChildren() do
		if child == objFrame then continue end
		child:RemoveTag("ObjSelected")
	end
end

local function updateAssetCounter()
	local children = GRID_SCROLL:GetChildren()

	assetCounterText.Text = ` {#children - 2} items`
end
-----------------------------
-- MAIN --
-----------------------------
local function createObjFrame(obj:Instance)
	if currentFilter then
		if currentFilter == "Models" and not obj:IsA("Model") then return end
		if currentFilter == "Meshes" and not (obj:IsA("BasePart") or obj:IsA("SurfaceAppearance")) then return end
		if currentFilter == "Audio" and not obj:IsA("Sound") then return end
		if currentFilter == "Images" and not (obj:IsA("Decal") or obj:IsA("Texture")) then return end
	end

	if currentSearchQuery and not string.find(obj.Name:lower(), currentSearchQuery:lower()) then return end
	
	local new = GRID_FRAME:Clone()
	if obj:HasTag("AV_FAVORITED") then new.Star.Visible = true end
	local VP = new.Background.ViewportFrame
	local VPCam = VP.VPCam
	VPCam.FieldOfView = 40
	
	if obj:IsA("Model") then
		local clone:Model = obj:Clone()
		local CF, VecSize = clone:GetBoundingBox()
		clone.Parent = VP
		
		clone:PivotTo(CFrame.new(Vector3.new(0,0,0) + (clone:GetPivot().Position-CF.Position) ))

		VPCam.CameraSubject = clone
		VPCam.CFrame = CFrame.new(Vector3.new(-1,.5,-1) * VecSize.Magnitude, Vector3.new(0,0,0))
		VP.CurrentCamera = VPCam
		return new
	end
	
	if obj:IsA("BasePart") then
		local clone:BasePart = obj:Clone()
		
		clone.Parent = VP
		
		clone:PivotTo(CFrame.new(Vector3.new(0,0,0)) + clone.PivotOffset.Position)

		VPCam.CameraSubject = clone
		VPCam.CFrame = CFrame.new(Vector3.new(-1,.5,-1) * clone.Size.Magnitude, Vector3.new(0,0,0))
		VP.CurrentCamera = VPCam
		return new
	end
	
	if obj:IsA("Sound") then
		new.Background.Image.Visible = true
		VP.Visible = false
		return new
	end
	
	if obj:IsA("SurfaceAppearance") then
		local ball = ASSETS.material_ball:Clone()
		obj:Clone().Parent = ball
		
		ball:PivotTo(CFrame.new(Vector3.new(0,0,0)))
		ball.Parent = VP
		
		VPCam.CFrame = CFrame.new(Vector3.new(0,0,-1) * ball.Size.Magnitude, Vector3.new(0,0,0))
		VP.CurrentCamera = VPCam
		return new
	end
	
	if obj:IsA("Decal") or obj:IsA("Texture") then
		local img = new.Background.Image
		img.Visible = true
		VP.Visible = false
		
		local txtData = obj.ColorMapContent.Uri
		txtData = string.match(txtData, "%d+")
		img.Image = "rbxassetid://"..txtData
		img.Size = UDim2.fromScale(.8,.8)
		return new
	end
	
	return nil
end

local function onSourceChanged()
	local source, inst = App.getSource()
	
	local inBuiltFolder, inBuiltSource = false, ""
	if inst then
		if inst.Name == "TOOLBOX" or inst.Name == "RECENT" or inst.Name == "FAVORITES" then
			inBuiltFolder, inBuiltSource = true, inst.Name
		end
	else
		if source == "TOOLBOX" or source == "RECENT" or source == "FAVORITES" then
			inBuiltFolder, inBuiltSource = true, source
		end
	end
	
	if inBuiltFolder and inBuiltSource == "TOOLBOX" then
		cleanupGrid()
		Signals.updateGridTexts:Fire("TEMP")
		--potential toolbox update
		return
	end
	if source == "None" then return end
	if not inst and not inBuiltFolder then
		warn(`>| AssetVault {env.Config:GetAttribute("version")} source folder instance not found, does the folder exist?`)
		Signals.updateGridTexts:Fire("INIT")
		cleanupGrid()
		return
	end

	local any = false
	local success, children = pcall(function() return inst:GetChildren() end)
	local sortByMethod = App.getSortBy()
	currentSettings = currentSettings or App.getSettings()
	
	cleanupGrid()
	
	if inBuiltFolder then
		if inBuiltSource == "FAVORITES" then
			children = CollectionService:GetTagged("AV_FAVORITED")
		elseif inBuiltSource == "RECENT" then
			children = Vault.getRecentInstances()
		end
	end
	
	if inBuiltSource ~= "RECENT" then
		if sortByMethod == "Name" then
			table.sort(children, function(a, b)
				return a.Name:lower() < b.Name:lower()
			end)
		elseif sortByMethod == "Instance" then
			sortChildrenByInstance(children)
		end
	end
	
	for _, obj in ipairs(children) do
		if obj:IsA("Folder") then continue end
		local new : Frame = createObjFrame(obj)
		if new then
			new.TextLabel.Text = truncateText(obj.Name)
			new:SetAttribute("TRUE_NAME", obj.Name)
			if currentSettings.ShowInstanceColors == true then
				new.TextLabel.TextColor3 = CLASS_COLORS[obj.ClassName] or CLASS_COLORS["DEFAULT"]
			end
			
			local wasSelectedOnDown = false

			new.ObjButton.InputBegan:Connect(function(input:InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					isClicking = true
					clickStartPos = input.Position
					wasSelectedOnDown = new:HasTag("ObjSelected")

					if not wasSelectedOnDown then
						updateSelectionOnObjectClick(new, input, true)
					end
					
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					if obj:HasTag("AV_FAVORITED") then
						new.Star.Visible = false
						obj:RemoveTag("AV_FAVORITED")
					else
						new.Star.Visible = true
						obj:AddTag("AV_FAVORITED")
					end
				end
			end)

			new.ObjButton.InputChanged:Connect(function(input)
				if isClicking and input.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = (input.Position - clickStartPos).Magnitude
					if delta > 5 then
						isClicking = false
						local selected = Dragger.getSelectedInstances()
						Dragger.startWorkspaceDrag(selected)
					end
				end
			end)

			new.ObjButton.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if isClicking and wasSelectedOnDown then
						updateSelectionOnObjectClick(new, input, false)
					end
					isClicking = false
				end
			end)
			
			new.Parent = GRID_SCROLL
			any = true
		end
	end
	
	if any then
		Signals.updateGridTexts:Fire("None")
	elseif currentFilter or currentSearchQuery then
		Signals.updateGridTexts:Fire("NoMatches")
	else
		Signals.updateGridTexts:Fire("EmptyFolder")
	end
	
	updateAssetCounter()
end

local function onSearchQueryChanged()
	local newSearch = App.getSearchQuery()
	if #newSearch == 0 then
		currentSearchQuery = nil
	else
		currentSearchQuery = newSearch
	end
	onSourceChanged()
end

local function onCategoryFilterChanged()
	local newFilter = App.getCategoryFilter()
	if newFilter == currentFilter then return end
	if newFilter == "All" then
		currentFilter = nil
	else
		currentFilter = newFilter
	end
	onSourceChanged()
end

local function onGridSizeChanged()
	local percentage = App.getGridSize()
	local newWidth = math.round(MAX_GRID_WIDTH * percentage)
	local newHeight = math.round(MAX_GRID_HEIGHT * percentage)
	
	local maxedWidth = math.max(newWidth, MIN_GRID_WIDTH)
	local maxedHeight = math.max(newHeight, MIN_GRID_HEIGHT)

	GRID_LAYOUT.CellSize = UDim2.new(0, maxedWidth, 0, maxedHeight)
end

-----------------------------
-- INIT --
-----------------------------
cleanupGrid()
onGridSizeChanged()

-----------------------------
-- CONNECTIONS --
-----------------------------
Signals.sourceChanged:Connect(onSourceChanged)
Signals.searchChanged:Connect(onSearchQueryChanged)
Signals.categoryChanged:Connect(onCategoryFilterChanged)
Signals.gridSizeChanged:Connect(onGridSizeChanged)
Signals.refreshClicked:Connect(onSourceChanged)
Signals.settingsChanged:Connect(function(arr)
	currentSettings = arr
end)

return Grid
