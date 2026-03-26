-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local Dragger = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules	
local ASSETS = env.Assets
type mainSchema = typeof(ASSETS.AV_Main)

-----------------------------
-- SERVICES --
-----------------------------
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local DraggerServ = game:GetService("DraggerService")
local Collection = game:GetService("CollectionService")
local CAS = game:GetService("ContextActionService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Pathfinder = require(MODULES.UI.Pathfinder)
local Signals = require(MODULES.API.Signals)
local App = require(MODULES.Core.AppState)
local Vault = require(MODULES.Core.VaultData)

-----------------------------
-- VARIABLES --
-----------------------------
local pluginIns : Plugin = nil
local pluginMouse = nil

local MAIN_DATA = Pathfinder:get("MAIN")
local mainGui : mainSchema = MAIN_DATA.UI
local mainWidget : DockWidgetPluginGui? = MAIN_DATA.WIDGET

local CURRENT_LIBRARY = mainGui.Main.CurrentLibrary

local targetFrame = CURRENT_LIBRARY.Grid
local overlayParent = CURRENT_LIBRARY.DraggerOverlay
local selectionBox = overlayParent.selectionBox
local conn = nil
local conn2 = nil
local currentSettings = {}

-- UI Selection State
local isDragging = false
local dragStartAbs = Vector2.zero
local dragInputConn = nil
local dragReleaseConn = nil

-- Workspace Drag State
local isDraggingToWorkspace = false
local workspaceDragInputConn = nil
local workspaceDragUpdateConn = nil
local draggingData = {}
local clonedInstances = {}
local lastValidTargetParent = workspace

-----------------------------
-- CONSTANTS --
-----------------------------
local CLASS_COLORS = {
	Decal = Color3.fromRGB(255, 150, 80),
	Texture = Color3.fromRGB(255, 150, 80),
	Sound = Color3.fromRGB(255, 100, 100),
	SurfaceAppearance = Color3.fromRGB(170, 130, 255)
}

-----------------------------
-- HELPER FUNCTIONS [UI] --
-----------------------------
local function clearSelection()
	if not targetFrame then return end
	for _, child in targetFrame:GetChildren() do
		if child:IsA("GuiObject") and child:HasTag("ObjSelected") then
			child:RemoveTag("ObjSelected")
		end
	end
end

local function updateSelection(minX, minY, maxX, maxY)
	for _, child in targetFrame:GetChildren() do
		if not child:IsA("GuiObject") then continue end

		local cMinX = child.AbsolutePosition.X
		local cMinY = child.AbsolutePosition.Y
		local cMaxX = cMinX + child.AbsoluteSize.X
		local cMaxY = cMinY + child.AbsoluteSize.Y

		if minX < cMaxX and maxX > cMinX and minY < cMaxY and maxY > cMinY then
			child:AddTag("ObjSelected")
		else
			child:RemoveTag("ObjSelected")
		end
	end
end

local function cleanupDrag()
	isDragging = false
	selectionBox.Visible = false

	if dragInputConn then
		dragInputConn:Disconnect()
		dragInputConn = nil
	end
	if workspaceDragInputConn then
		workspaceDragInputConn:Disconnect()
		workspaceDragInputConn = nil
	end
	if dragReleaseConn then
		dragReleaseConn:Disconnect()
		dragReleaseConn = nil
	end
end

local function getInstanceByFrame(gridFrame:Frame)
	local source, source_instance = App.getSource()
	
	local name = gridFrame:GetAttribute("TRUE_NAME") or gridFrame.TextLabel.Text
	
	if source == "FAVORITES" then
		for _, obj in Collection:GetTagged("AV_FAVORITED") do
			if obj.Name == name then
				return obj
			end
		end
		warn("AV: Failed to find favorited object with name ", name)
		return nil
	end

	if not source_instance then return end

	local obj = source_instance:FindFirstChild(name)
	if obj then
		return obj
	end
	warn("AV: Failed to find object with name ", name)
	return
end

-----------------------------
-- HELPER FUNCTIONS (WORKSPACE DRAG)
-----------------------------
local function generateSpiralOffsets(count: number, stepSize: number)
	local offsets = {}
	if count == 0 then return offsets end

	table.insert(offsets, Vector3.zero) 
	if count == 1 then return offsets end

	local x, z = 0, 0
	local dx, dz = 1, 0
	local segmentLength = 1
	local segmentPassed = 0

	for i = 2, count do
		x += dx
		z += dz
		segmentPassed += 1

		table.insert(offsets, Vector3.new(x * stepSize, 0, z * stepSize))

		if segmentPassed == segmentLength then
			segmentPassed = 0
			local temp = dx
			dx = -dz
			dz = temp

			if dz == 0 then
				segmentLength += 1
			end
		end
	end
	return offsets
end

local function snapPosition(position: Vector3, gridSize: number)
	if gridSize <= 0 then return position end

	return Vector3.new(
		math.round(position.X / gridSize) * gridSize,
		math.round(position.Y / gridSize) * gridSize,
		math.round(position.Z / gridSize) * gridSize
	)
end

local function getSurfaceData(unitRay: Ray, excludeInstances)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = excludeInstances

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
	if result then
		return result.Position, result.Normal
	end

	return unitRay.Origin + unitRay.Direction * 100, Vector3.yAxis 
end

local function cleanupWorkspaceDrag()
	isDraggingToWorkspace = false
	if workspaceDragUpdateConn then
		workspaceDragUpdateConn:Disconnect()
		workspaceDragUpdateConn = nil
	end
	
	draggingData = {}
	clonedInstances = {}
end

local function cancelWorkspaceDrag()
	for _, clone in ipairs(clonedInstances) do
		clone:Destroy()
	end
	cleanupWorkspaceDrag()
end

local function finishWorkspaceDrag()
	if not isDraggingToWorkspace then return end

	Selection:Set(clonedInstances)
	
	CAS:UnbindAction("AssetVault_Rotate")
	
	ChangeHistoryService:SetWaypoint("Inserted AssetVault Instances")
	cleanupWorkspaceDrag()
end

local function deleteInput(input:InputObject)
	if input then
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode ~= Enum.KeyCode.Delete then return end
	end

	Selection:Set{}

	local instancesDeleted = false

	for _, child in targetFrame:GetChildren() do
		if not child:IsA("GuiObject") then continue end
		if not child:HasTag("ObjSelected") then continue end

		local ins = getInstanceByFrame(child)
		if ins then 
			ins.Parent = nil 
			instancesDeleted = true
		end

		child:Destroy()
	end

	if instancesDeleted then
		ChangeHistoryService:SetWaypoint("Deleted AssetVault Instances")
	end
end

-----------------------------
-- CORE --
-----------------------------
--Workspace dragger
function Dragger.getSelectedInstances(withFrames)
	withFrames = withFrames or false
	
	local selectedInstances = {}
	for _, child in targetFrame:GetChildren() do
		if not child:IsA("GuiObject") then continue end
		if not child:HasTag("ObjSelected") then continue end
		local ins = getInstanceByFrame(child)
		if ins then
			if withFrames then
				table.insert(selectedInstances, {child, ins})
			else
				table.insert(selectedInstances, ins)
			end
		end
	end
	return selectedInstances
end

function Dragger.startWorkspaceDrag(selectedInstances)
	if #selectedInstances == 0 or isDraggingToWorkspace then return end

	isDraggingToWorkspace = true
	draggingData = {}
	clonedInstances = {}

	local maxSize = 0
	local applyAutoAnchor = currentSettings.AutoAnchor
	local targetParent = workspace
	local currentSelection = Selection:Get()
	local currentDragRotation = 0
	local firstFolder, firstModel
	local isUserSelection = true
	
	CAS:BindAction("AssetVault_Rotate", function(actionName, inputState, input)
		if inputState == Enum.UserInputState.Change then
			local increment = 3

			if DraggerServ.AngleSnapEnabled then
				increment = DraggerServ.AngleSnapIncrement
			end

			if input.Position.Z > 0 then
				currentDragRotation += math.rad(increment)
			elseif input.Position.Z < 0 then
				currentDragRotation -= math.rad(increment)
			end

			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseWheel)
	
	if #currentSelection > 0 and #clonedInstances > 0 then
		if currentSelection[1] == clonedInstances[1] then
			isUserSelection = false
		end
	end
	
	if isUserSelection then
		for _, sel in ipairs(currentSelection) do
			if sel:IsA("Folder") and not firstFolder then
				firstFolder = sel
			elseif sel:IsA("Model") and not firstModel then
				firstModel = sel
			end
		end
		
		if firstFolder or firstModel then
			lastValidTargetParent = firstFolder or firstModel
		end
	end
	
	targetParent = lastValidTargetParent
	
	if not targetParent:IsDescendantOf(workspace) or targetParent:GetAttribute("VaultUUID") ~= nil then
		targetParent = workspace
		lastValidTargetParent = workspace
	end
	
	for _, instance in ipairs(selectedInstances) do
		if instance.Parent then
			local parentUUID = instance.Parent:GetAttribute("VaultUUID")
			if parentUUID then
				Vault.addRecentItem(parentUUID, instance.Name)
			end
		end
	end

	for _, instance:Instance in ipairs(selectedInstances) do
		local clone

		if instance:IsA("Decal") or instance:IsA("Sound") or instance:IsA("SurfaceAppearance") then
			clone = instance:IsA("SurfaceAppearance") and Instance.new("MeshPart") or Instance.new("Part")
			clone.Material = Enum.Material.SmoothPlastic
			clone.Size = Vector3.new(4, 4, 4)
			if applyAutoAnchor then clone.Anchored = true end
			clone.Color = CLASS_COLORS[instance.ClassName] or Color3.new(1, 1, 1)

			if instance.ClassName == "Decal" then
				local instClone = instance:Clone()
				instClone.Face = Enum.NormalId.Front
				instClone.Parent = clone
				
			elseif instance.ClassName == "Texture" then
				for _, face in Enum.NormalId:GetEnumItems() do
					local instClone = instance:Clone()
					instClone.Name = face.Name
					instClone.Face = face
					instClone.Parent = clone
				end
				
			elseif instance.ClassName == "SurfaceAppearance" then
				local instClone = instance:Clone()
				instClone.Parent = clone
			
				
			elseif instance:IsA("Sound") then
				local instClone = instance:Clone()
				instClone.Parent = clone
			end
		elseif instance:IsA("Script") or instance:IsA("ModuleScript") then
			continue
		else
			
			clone = instance:Clone()
			if applyAutoAnchor then
				if clone:IsA("BasePart") then clone.Anchored = true end
				
				for _, desc in clone:GetDescendants() do
					if desc:IsA("BasePart") then desc.Anchored = true end
				end
			end
		end

		clone.Parent = targetParent
		table.insert(clonedInstances, clone)

		local size = clone:IsA("Model") and select(2, clone:GetBoundingBox()) or clone.Size
		maxSize = math.max(maxSize, size.X, size.Z)
	end

	local stepSize = maxSize * .8
	local offsets = generateSpiralOffsets(#clonedInstances, stepSize)

	for i, clone in ipairs(clonedInstances) do
		local cframe, size
		if clone:IsA("Model") then
			cframe, size = clone:GetBoundingBox()
		else
			cframe, size = clone.CFrame, clone.Size
		end
		local pivotOffset = clone:GetPivot():ToObjectSpace(cframe)
		local yOffset = (size.Y / 2) - pivotOffset.Position.Y

		table.insert(draggingData, {
			clone = clone,
			localOffset = offsets[i],
			yOffset = yOffset
		})
	end
	
	workspaceDragUpdateConn = RunService.RenderStepped:Connect(function()
		if not pluginMouse then return end
		
		local targetPos, surfaceNormal = getSurfaceData(pluginMouse.UnitRay, clonedInstances)
		if DraggerServ.LinearSnapEnabled then
			targetPos = snapPosition(targetPos, DraggerServ.LinearSnapIncrement)
		end
		
		local alignToNormal = currentSettings.AlignToNormal ~= false

		local upVector = alignToNormal and surfaceNormal or Vector3.yAxis

		local right = Vector3.zAxis:Cross(upVector)
		if right.Magnitude < 0.001 then
			right = Vector3.xAxis:Cross(upVector)
		end
		right = right.Unit
		local forward = upVector:Cross(right).Unit

		local baseCFrame = CFrame.fromMatrix(targetPos, right, upVector, -forward)

		for _, data in ipairs(draggingData) do
			local finalCFrame = baseCFrame 
				* CFrame.new(data.localOffset)
				* CFrame.Angles(0, currentDragRotation, 0)
				* CFrame.new(0, data.yOffset, 0)

			if data.clone:IsA("Model") then
				data.clone:PivotTo(finalCFrame)
			elseif data.clone:IsA("BasePart") then
				data.clone.CFrame = finalCFrame
			end
		end
	end)

	workspaceDragInputConn = UIS.InputBegan:Connect(function(input, gameProcessed)
		if not isDraggingToWorkspace then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			finishWorkspaceDrag()

		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			cancelWorkspaceDrag()
			
		end
	end)
end

-- Visual dragger on UI
local function onInputBegan(input:InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	cleanupDrag()

	isDragging = true
	dragStartAbs = Vector2.new(input.Position.X, input.Position.Y)

	selectionBox.Position = UDim2.fromOffset(dragStartAbs.X - overlayParent.AbsolutePosition.X, dragStartAbs.Y - overlayParent.AbsolutePosition.Y)
	selectionBox.Size = UDim2.fromOffset(1,1)
	selectionBox.Visible = true

	clearSelection()

	dragInputConn = overlayParent.InputChanged:Connect(function(moveInput)
		if not isDragging or moveInput.UserInputType ~= Enum.UserInputType.MouseMovement then return end

		local currentAbs = moveInput.Position

		local minX = math.min(dragStartAbs.X, currentAbs.X)
		local minY = math.min(dragStartAbs.Y, currentAbs.Y)
		local maxX = math.max(dragStartAbs.X, currentAbs.X)
		local maxY = math.max(dragStartAbs.Y, currentAbs.Y)

		selectionBox.Position = UDim2.fromOffset(minX - overlayParent.AbsolutePosition.X, minY - overlayParent.AbsolutePosition.Y)
		selectionBox.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
		
		updateSelection(minX, minY, maxX, maxY)
	end)

	dragReleaseConn = mainGui.InputEnded:Connect(function(releaseInput)
		if releaseInput.UserInputType == Enum.UserInputType.MouseButton1 then
			cleanupDrag()
		end
	end)
end

-----------------------------
-- MAIN --
-----------------------------
function Dragger.init(instance)
	pluginIns = instance
	pluginMouse = instance:GetMouse()
	conn = targetFrame.InputBegan:Connect(onInputBegan)
	conn2 = targetFrame.InputBegan:Connect(deleteInput)
	currentSettings = App.getSettings()
	
end

local function onPluginUnloading()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if conn2 then
		conn2:Disconnect()
		conn2 = nil
	end
	cancelWorkspaceDrag()
end

-----------------------------
-- CONNECTIONS --
-----------------------------
Signals.onPluginUnloading:Connect(onPluginUnloading)
Signals.settingsChanged:Connect(function(newSettings)
	currentSettings = newSettings
end)

ChangeHistoryService.OnUndo:Connect(function(waypoint)
	if waypoint == "Deleted AssetVault Instances" or waypoint == "Renamed AssetVault Instances" or waypoint == "Moved AssetVault Instances" then
		Signals.refreshClicked:Fire()
	end
end)

return Dragger