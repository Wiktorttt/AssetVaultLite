local Pathfinder = {}

type typeRegistry = {
	UI: Instance?,
	WIDGET: DockWidgetPluginGui?
}
local registeredData: { [string]: typeRegistry } = {}

function Pathfinder:registerData(data: { [string]: typeRegistry })
	for key, entry in pairs(data) do
		registeredData[key] = entry
	end
	--print("Registered", registeredData)
end

function Pathfinder:get(key: string): typeRegistry
	local entry = registeredData[key]
	if not entry then
		warn(string.format(">| Pathfinder - Entry '%s' not found.", key))
		return { UI = nil, WIDGET = nil }
	end
	return entry
end


return Pathfinder
