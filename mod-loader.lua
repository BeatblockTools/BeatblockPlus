bbp = {
	mods = {}
}
-- TODO: remove this later due to deprecation
mods = bbp.mods

local function readJsonFromFile(filePath)
	local contents = love.filesystem.read(filePath)
	return json.decode(contents)
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

local function moveDirectory(source, target)
    love.filesystem.createDirectory(target)

    local files = love.filesystem.getDirectoryItems(source)
    for _, file in pairs(files) do
        local sourceFilePath = source .. file
        local targetFilePath = target .. file

        local contents = love.filesystem.read(sourceFilePath)
        if contents then
            local targetFile = love.filesystem.newFile(targetFilePath)
            targetFile:open("w")
            targetFile:write(contents)
            targetFile:flush()
            love.filesystem.remove(sourceFilePath)
        end
    end

    love.filesystem.remove(source)
end

local function setModChunkEnvironment(chunk, mod, setDeprecated)
	local env = setmetatable({}, {
		__index = function(t, k)
			if k == "bbp" then
				return {
					mods = bbp.mods,
					mod = mod
				}
			end
			-- TODO: remove this later due to deprecation
			-- all of this information is accessible through bbp.mod
			if setDeprecated then
				if k == "modId" then
					return mod.id
				end
				if k == "modPath" then
					return mod.path
				end
				if k == "modData" then
					return mod
				end
				if k == "mod" then
					return mod
				end
			end
			return _G[k]
		end,
		__newindex = _G
	})
	return setfenv(chunk, env)
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

local function mergeLangFiles(originalLoc, modLoc)
	local selectedLanguage = savedata.options.language
	for key, value in pairs(modLoc) do
		if not originalLoc[key] then
			originalLoc[key] = {}
		end
		originalLoc[key][selectedLanguage] = value
	end
end

function tableContains(t, v)
	for i = 1, #t do
		if (t[i] == v) then
			return true
		end
	end
	return false
end

local function getParent(fullPath)
	return fullPath:match("(.*/)") or "."
end

function string:endswith(ending)
	return ending == "" or self:sub(- #ending) == ending
end

local function getModConfigRenderer(mod)
	if mod._configRenderer == false then
		return nil
	end

	local path = mod.path .. "/config.lua"
	if not love.filesystem.getInfo(path, 'file') then
		rawset(mod, '_configRenderer', false)
		return nil
	end

	local chunk, errormsg = love.filesystem.load(path)
	if errormsg then
		print("[BB+] Error while loading the config renderer of " .. mod.name .. ". " .. errormsg)
		rawset(mod, '_configRenderer', false)
		return nil
	end

	rawset(mod, '_configRenderer', setModChunkEnvironment(chunk, mod, true))
	if mod._configRenderer == nil then
		print("[BB+] Error while loading the config renderer of " .. mod.name .. ". Unknown error.")
		rawset(mod, '_configRenderer', false)
		return nil
	end

	return mod._configRenderer
end

local function setModEnabled(mod, enabled)
	if enabled == nil then
		enabled = true
	end
	local createFilePath = mod.path .. (enabled and "/.nolovelyignore" or "/.lovelyignore")
	local deleteFilePath = mod.path .. (enabled and "/.lovelyignore" or "/.nolovelyignore")
	local success = true
	if not love.filesystem.getInfo(createFilePath, 'file') then
		success = success and love.filesystem.write(createFilePath, "")
	end
	if love.filesystem.getInfo(deleteFilePath, 'file') then
		success = success and love.filesystem.remove(deleteFilePath)
	end
	if not success then
		return
	end
	rawset(mod, '_enabled', enabled)
end

function loadMods() -- loads mod data, assets, mod icons etc.
	local modsPath = "Mods"
	local success = love.filesystem.getInfo(modsPath, 'directory')

	if not success then
		print("[BB+] Failed to find Mods directory. Mods won't be loaded.")
		return
	end

	for _, modDir in ipairs(love.filesystem.getDirectoryItems(modsPath)) do
		if modDir == "lovely" then
			goto continue
		end

		local mod = {
			path = modsPath .. "/" .. modDir,
			id = modDir,
			name = modDir,
			author = "Unknown",
			description = "",
			version = "1.0.0",
			icon = nil,
			defaultConfig = {},
			config = {}
		}
		setmetatable(mod, {
			__index = function(t, k)
				if k == "enabled" then
					return t._enabled
				elseif k == "configRenderer" then
					return getModConfigRenderer(t)
				end
				return rawget(t, k)
			end,
			__newindex = function(t, k, v)
				if k == "enabled" then
					setModEnabled(t, v)
				end
			end
		})

		if not love.filesystem.getInfo(mod.path, 'directory') then
			goto continue
		end

		local lovelyignore = love.filesystem.getInfo(mod.path .. "/.lovelyignore", 'file')
		local nolovelyignore = love.filesystem.getInfo(mod.path .. "/.nolovelyignore", 'file')
		if lovelyignore ~= nil then
			mod.enabled = false
		elseif nolovelyignore ~= nil then
			mod.enabled = true
		end

		-- load mod data if it exists
		if love.filesystem.getInfo(mod.path .. "/mod.json", 'file') then
			local modData = readJsonFromFile(mod.path .. "/mod.json")
			mod.id = modData.id or mod.id
			mod.name = modData.name or mod.name
			mod.author = modData.author or mod.author
			mod.description = modData.description or mod.description
			mod.version = modData.version or mod.version
			mod.defaultConfig = modData.config or mod.defaultConfig
			mod.config = helpers.copytable(mod.defaultConfig)

			-- TODO: deprecated
			if modData.enabled ~= nil then
				print("[BB+] '" .. mod.path .. "/mod.json" .. "': 'enabled' is deprecated in favor of the .lovelyignore file")
				if mod.enabled == nil then
					mod.enabled = modData.enabled
					if modData.enabled == false then
						local disabledPath = "Mods/disabled/" .. mod.id .. "/lovely/"
						if love.filesystem.getInfo(disabledPath, 'directory') then
							moveDirectory(disabledPath, mod.path .. "/lovely/")
						end
					end
				end
			end
		end
		if mod.enabled == nil then
			mod.enabled = true
		end

		-- load mod config if it exists
		if love.filesystem.getInfo(mod.path .. "/config.json", 'file') then
			local modConfig = readJsonFromFile(mod.path .. "/config.json")
			if modConfig then
				-- a shallow copy is enough in this case
				for k, v in pairs(modConfig) do
					mod.config[k] = v
				end
			end
		end

		-- load mod icon if it exists
		if love.filesystem.getInfo(mod.path .. "/icon.png", 'file') then
			local modIcon = love.graphics.newImage(mod.path .. "/icon.png")
			local width, height = modIcon:getDimensions()
			if width ~= 73 or height ~= 33 then
				print("[BB+] Mod " .. mod.id .. " has invalid icon size. Mod icons must be 73x33.")
			else
				rawset(mod, "icon", modIcon)
			end
		end

		bbp.mods[mod.id] = mod
		print("[BB+] Registered mod '" .. mod.name .. "' by " .. mod.author .. ".")

		if not mod.enabled then
			goto continue
		end

		-- load assets
		local assetsPath = mod.path .. "/assets"
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

			loopFiles(loc.json, assetsPath .. "/lang", function(tbl, path, fileName)
				table.insert(customLanguages, fileName)
				-- make sure we don't load english lang when owo is selected
				if fileName == savedata.options.language then
					print("[BB+] injecting lang file " .. path .. "...")
					local modLoc = dpf.loadJson(path, {})
					mergeLangFiles(loc.json, modLoc)
				end
			end)
		end

		-- load states
		loopFiles({}, mod.path .. "/states", function(_, path, fileName)
			print("[BB+] injecting state " .. path .. "...")
			bs.fromPath(fileName, path)
			if bs.states[fileName] then
				setModChunkEnvironment(bs.states[fileName], mod)
			end
		end)

		-- load entities
		loopFiles({}, mod.path .. "/entities", function(_, path, fileName)
			print("[BB+] injecting entity " .. path .. "...")
			em.new(path, fileName)
			if em.entities[fileName] then
				setModChunkEnvironment(bs.states[fileName], mod)
			end
		end)

		-- load and call main.lua
		if love.filesystem.getInfo(mod.path .. "/main.lua") then
			local chunk, errormsg = love.filesystem.load(mod.path .. "/main.lua")
			if errormsg then
				print("[BB+] Error while loading the main.lua file of '" .. mod.id .. "': " .. errormsg)
			else
				setModChunkEnvironment(chunk, mod, true)()
			end
		end
		::continue::
	end

	print("[BB+] Finished loading all mods! :D")
	printTable(animations, 3, "Animations:")
	printTable(sprites, 3, "Sprites:")
	printTable(sounds, 3, "Sounds:")
	printTable(shaders, 3, "Shaders:")
end

function getModNames()
	local modNames = {}

	for _, mod in pairs(bbp.mods) do
		table.insert(modNames, "  - " .. mod.name .. " (" .. mod.version .. ") by " .. mod.author)
	end

	return table.concat(modNames, "\n")
end
