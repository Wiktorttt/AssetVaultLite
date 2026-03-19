local module = {}

function module.x(instance : Instance)
	if not instance:IsA("Folder") or instance:HasTag("VaultRoot") then return false end
	if instance.Parent and instance.Parent:HasTag("VaultRoot") then return false end
	if instance.Parent.Parent and instance.Parent.Parent:HasTag("VaultRoot") then return false end
	return true
end

return module
