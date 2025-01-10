local json = require "lib.json"
mods = {}

local function readJsonFromFile(filePath)
	local contents = love.filesystem.read(filePath)
	return json.decode(contents)
end

local function registerMod(modData)
	local id = modData.id
	local name = modData.name or "Unknown"
	local author = modData.author or "Unknown"
	local description = modData.description or ""
	local version = modData.version or "1.0.0"

	table.insert(mods, { id = id, name = name, author = author, description = description, version = version })
	print("Registered mod '" .. name .. "' by " .. author .. ".")
end

function loadMods()
	local modsPath = "Mods"
	local success = love.filesystem.getInfo(modsPath, "directory")

	if success then
		for _, modName in ipairs(love.filesystem.getDirectoryItems(modsPath)) do
			local modPath = modsPath .. "/" .. modName
			if love.filesystem.getInfo(modPath, "directory") then
				if love.filesystem.getInfo(modPath .. "/mod.json", "file") then
					local modData = readJsonFromFile(modPath .. "/mod.json")
					registerMod(modData)
				end
			end
		end
	else
		print("Failed to find Mods directory.")
	end
end

function getModNames()
	local modNames = {}

	for _, mod in ipairs(mods) do
		table.insert(modNames, mod.name)
	end

	return table.concat(modNames, ", ")
end