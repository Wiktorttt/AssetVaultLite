-- // Copyright 2026, wiktorttt, All rights reserved by These Two.
--===============================================================
local Vault = {}
local env = script.Parent.Parent.Parent
local UTILS = env.Utils
local MODULES = env.Modules

-----------------------------
-- SERVICES --
-----------------------------
local HTTP = game:GetService("HttpService")
local Collection = game:GetService("CollectionService")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local Signals = require(MODULES.API.Signals)

-----------------------------
-- VARIABLES --
-----------------------------
local pluginIns : Plugin = nil

Vault.rootUUIDs = {}
Vault.recentItems = {}

-----------------------------
-- HELPER FUNCTIONS --
-----------------------------
local function getOrGenerateUUID(instance: Instance): string
	local existingId = instance:GetAttribute("VaultUUID")
	if existingId then
		return existingId
	end

	local newId = HTTP:GenerateGUID(false)
	instance:SetAttribute("VaultUUID", newId)
	return newId
end


local function getValidRoots()
	local validRoots = {}
	local tagged = Collection:GetTagged("VaultRoot")

	for _, instance in tagged do
		local uuid = instance:GetAttribute("VaultUUID")
		if uuid and table.find(Vault.rootUUIDs, uuid) then
			table.insert(validRoots, instance)
		end
	end
	return validRoots
end

-----------------------------
-- CORE --
-----------------------------
function Vault.getLibrariesWithChildren()
	local output = {}

	local roots = getValidRoots()
	
	for _, rootInstance in roots do
		local rootUUID = getOrGenerateUUID(rootInstance)

		local rootEntry = {
			Instance = rootInstance,
			Name = rootInstance.Name,
			UUID = rootUUID,
			ParentUUID = nil,
			isExpanded = false,
			isExpandable = false
		}

		table.insert(output, rootEntry)
	end

	local dataChanged = false	
	local validRootUUIDs = {}
	for _, instance in roots do
		table.insert(validRootUUIDs, instance:GetAttribute("VaultUUID"))
	end

	for i = #Vault.rootUUIDs, 1, -1 do
		local uuid = Vault.rootUUIDs[i]
		if not table.find(validRootUUIDs, uuid) then
			table.remove(Vault.rootUUIDs, i)
			dataChanged = true
		end
	end

	if dataChanged then Vault.save() end

	return output
end

-----------------------------
-- MAIN --
-----------------------------
function Vault.init(instance)
	pluginIns = instance
end

function Vault.save()
	if not pluginIns then
		warn(">| AssetVault: Plugin not initialized. Data not saved.")
		return
	end

	local saveData = {
		Roots = Vault.rootUUIDs,
		Recent = Vault.recentItems
	}

	pluginIns:SetSetting("AssetVaultDataLite", saveData)
end

function Vault.load()
	if not pluginIns then
		warn(">| AssetVault: Plugin not initialized. Data not loaded.")
		return
	end
	
	local savedData = pluginIns:GetSetting("AssetVaultDataLite") or {}
	Vault.rootUUIDs = savedData.Roots or {}
	Vault.recentItems = savedData.Recent or {}

	Signals.libraryTreeChanged:Fire(Vault.getLibrariesWithChildren())
end

function Vault.appendLibraries(folderInstancesArray: {Folder})
	if #folderInstancesArray == 0 then return end
	
	local folderInstance = folderInstancesArray[1]
	if not folderInstance:IsA("Folder") then
		warn(">| AssetVault: Cannot append a non-folder instance.")
		return
	end
	
	local uuid = getOrGenerateUUID(folderInstance)
	if table.find(Vault.rootUUIDs, uuid) then
		warn(`>| AssetVault: Library {folderInstance.Name} already exists.`)
		return
	end

	folderInstance:AddTag("VaultRoot")
	table.insert(Vault.rootUUIDs, uuid)

	Vault.save()
	Signals.libraryTreeChanged:Fire(Vault.getLibrariesWithChildren())
end

function Vault.removeLibrary(UUID: string)
	local index = table.find(Vault.rootUUIDs, UUID)
	if index then
		table.remove(Vault.rootUUIDs, index)

		for _, instance in Collection:GetTagged("VaultRoot") do
			if instance:GetAttribute("VaultUUID") == UUID then
				instance:RemoveTag("VaultRoot")
				break
			end
		end

		Vault.save()
		Signals.libraryTreeChanged:Fire(Vault.getLibrariesWithChildren())
	end
end


function Vault.addRecentItem(parentUUID: string, itemName: string)
	for i, v in ipairs(Vault.recentItems) do
		if v.parentUUID == parentUUID and v.name == itemName then
			table.remove(Vault.recentItems, i)
			break
		end
	end

	table.insert(Vault.recentItems, 1, {parentUUID = parentUUID, name = itemName})

	if #Vault.recentItems > 15 then
		table.remove(Vault.recentItems, 16)
	end

	Vault.save()
end

function Vault.getRecentInstances()
	local instances = {}

	for _, item in ipairs(Vault.recentItems) do
		local parentFolder = nil

		for _, root in Collection:GetTagged("VaultRoot") do
			if root:GetAttribute("VaultUUID") == item.parentUUID then 
				parentFolder = root 
				break 
			end
		end

		if parentFolder then
			local obj = parentFolder:FindFirstChild(item.name)
			if obj then table.insert(instances, obj) end
		end
	end

	return instances
end

return Vault
