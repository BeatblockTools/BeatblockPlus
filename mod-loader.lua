mods = {}
modIcons = { unknown = love.graphics.newImage("Mods/beatblock-plus/unknown.png") }

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
	print("[BB+] Registered mod '" .. name .. "' by " .. author .. ".")
end

-- files.walk implementation
local function loopFiles(tbl, dir, callback)
	local function recurse(currentTable, currentDir)
		for _, item in ipairs(love.filesystem.getDirectoryItems(currentDir)) do
			local fullPath = currentDir .. "/" .. item
			if love.filesystem.getInfo(fullPath, "directory") then
				currentTable[item] = currentTable[item] or {}
				recurse(currentTable[item], fullPath)
			else
				local fileName = item:match("([^/]+)$"):gsub("%..+$", "") -- extract the file name without the directory and extension
				callback(currentTable, fullPath, fileName)
			end
		end
	end

	recurse(tbl, dir)
end

local function printTable(t, indent, title)
	if title then
		print(title)
	end
	indent = indent or 0
	local indentStr = string.rep("  ", indent)

	for k, v in pairs(t) do
		if type(v) == "table" then
			print(indentStr .. tostring(k) .. ":")
			printTable(v, indent + 1)
		else
			print(indentStr .. tostring(k) .. ": " .. tostring(v))
		end
	end
end

local function getParent(fullPath)
  return fullPath:match("(.*/)") or "."
end

function string:endswith(ending)
	return ending == "" or self:sub(-#ending) == ending
end

function loadMods() -- loads mod data, assets, mod icons etc.
	local modsPath = "Mods"
	local success = love.filesystem.getInfo(modsPath, 'directory')

	if not success then
		print("[BB+] Failed to find Mods directory. Mods won't be loaded.")
		return
	end

	for _, modId in ipairs(love.filesystem.getDirectoryItems(modsPath)) do
		local modPath = modsPath .. "/" .. modId
		if love.filesystem.getInfo(modPath, 'directory') then
			-- load mod data if it exists
			local modData
			if love.filesystem.getInfo(modPath .. "/mod.json", 'file') then
				modData = readJsonFromFile(modPath .. "/mod.json")
				registerMod(modData)
			end

			-- load mod icon if it exists
			if love.filesystem.getInfo(modPath .. "/icon.png", 'file') then
				local modIcon = love.graphics.newImage(modPath .. "/icon.png")
				local width, height = modIcon:getDimensions()
				if width ~= 73 or height ~= 33 then
					print("[BB+] Mod " .. modId .. " has invalid icon size. Mod icons must be 73x33.")
				else
					modIcons[modId] = modIcon
				end
			end

			-- load assets
			local assetsPath = modPath .. "/assets"
			if love.filesystem.getInfo(assetsPath, 'directory') then
				-- load sprites
				loopFiles(sprites, assetsPath .. "/textures", function(tbl, path, fileName)
					print("[BB+] injecting sprite " .. path .. "...")
					tbl[fileName] = love.graphics.newImage(path)
				end)

				-- load sounds
				loopFiles(sounds, assetsPath .. "/sounds", function(tbl, path, fileName)
					print("[BB+] injecting sound " .. path .. "...")
					tbl[fileName] = love.sound.newSoundData(path)
				end)

				-- load shaders
				loopFiles(shaders, assetsPath .. "/shaders", function(tbl, path, fileName)
					print("[BB+] injecting shader " .. path .. "...")
					tbl[fileName] = love.graphics.newShader(path)
				end)

				-- load animations
				loopFiles(animations, assetsPath .. "/animations", function(tbl, path, fileName)
					if path:endswith(".png") then
						print("[BB+] injecting animation " .. path .. "...")
						local data = getParent(path) .. "data.json"
						if not love.filesystem.getInfo(data, 'file') then
							print("[BB+] Error while injecting animation '" .. path .. "'. The '" .. data .. "' file is missing!")
						end
						tbl[fileName] = ez.newjson(path, data)
					end
				end)
			end

			-- load states
			loopFiles({}, modPath .. "/states", function(_, path, fileName)
				print("[BB+] injecting state " .. path .. "...")
				bs.new(fileName, path)
			end)

			-- load entities
			loopFiles({}, modPath .. "/entities", function(_, path, fileName)
				print("[BB+] injecting entity " .. path .. "...")
				em.new(path, fileName)
			end)

			-- load and call main.lua
			if love.filesystem.getInfo(modPath .. "/main.lua") then
				local chunk, errormsg = love.filesystem.load(modPath .. "/main.lua")
				if errormsg then
					print("[BB+] Error while loading the main.lua file of '" .. modId .. "': " .. errormsg)
				else
					local env = setmetatable({ modId = modId, modPath = modPath, modData = modData }, { __index = _G })
					setfenv(chunk, env)()
				end
			end
		end
	end

	print("[BB+] Finished loading all mods! :D")
	printTable(animations, 3, "Animations:")
	printTable(sprites, 3, "Sprites:")
	printTable(sounds, 3, "Sounds:")
	printTable(shaders, 3, "Shaders:")
	printTable(modIcons, 3, "Mod icons:")
end

function getModNames() -- format: mod1, mod2, mod3
	local modNames = {}

	for _, mod in ipairs(mods) do
		table.insert(modNames, mod.name)
	end

	return table.concat(modNames, ", ")
end