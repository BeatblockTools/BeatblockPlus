local loader = {}

local function setModChunkEnvironment(chunk, mod, setDeprecated)
	local env = setmetatable({}, {
		__index = function(t, k)
			if k == "mod" then
				return mod
			end

			-- TODO: remove this later due to deprecation
			-- all of this information is accessible through 'mod'
			if setDeprecated then
				if k == "modId" then
					log("The mod " .. mod.id ..
						      " is using the deprecated 'modId' variable which will be removed in a future version. You should use 'mod.id' instead!","BBP")
					return mod.id
				end
				if k == "modPath" then
					log("The mod " .. mod.id ..
						      " is using the deprecated 'modPath' variable which will be removed in a future version. You should use 'mod.path' instead!","BBP")
					return mod.path
				end
				if k == "modData" then
					log("The mod " .. mod.id ..
						      " is using the deprecated 'modData' variable which will be removed in a future version. You should use 'mod' instead!","BBP")
					return mod
				end
			end

			return _G[k]
		end,
		__newindex = _G
	})
	return setfenv(chunk, env)
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
		log("Error while loading the config renderer of " .. mod.name .. ". " .. errormsg,"BBP")
		rawset(mod, '_configRenderer', false)
		return nil
	end

	rawset(mod, '_configRenderer', setModChunkEnvironment(chunk, mod, true))
	if mod._configRenderer == nil then
		log("Error while loading the config renderer of " .. mod.name .. ". Unknown error.","BBP")
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

function loader.loadMods() -- loads mod data, assets, mod icons etc.
	loader.mods = {}

	-- TODO: remove this later due to deprecation
	mods = loader.mods

	local modsPath = "Mods"
	local success = love.filesystem.getInfo(modsPath, 'directory')

	if not success then
		log("Failed to find Mods directory. Mods won't be loaded.","BBP")
		return
	end

	for _, modDir in ipairs(love.filesystem.getDirectoryItems(modsPath)) do
		if not love.filesystem.getInfo(modsPath .. "/" .. modDir .. "/mod.json", 'file') then
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

		-- load mod data
		local modData = dpf.loadJson(mod.path .. "/mod.json")
		mod.id = modData.id or mod.id
		mod.name = modData.name or mod.name
		mod.author = modData.author or mod.author
		mod.description = modData.description or mod.description
		mod.version = modData.version or mod.version
		mod.defaultConfig = modData.config or mod.defaultConfig
		mod.config = helpers.copytable(mod.defaultConfig)
		-- TODO: deprecated
		if modData.enabled ~= nil then
			log("'" .. mod.path .. "/mod.json" .. "': 'enabled' is deprecated in favor of the .lovelyignore file","BBP")
			if mod.enabled == nil then
				mod.enabled = modData.enabled
				if modData.enabled == false then
					local disabledPath = "Mods/disabled/" .. mod.id .. "/lovely/"
					if love.filesystem.getInfo(disabledPath, 'directory') then
						bbp.utils.moveDirectory(disabledPath, mod.path .. "/lovely/")
					end
				end
			end
		end

		if mod.enabled == nil then
			mod.enabled = true
		end

		-- load mod config if it exists
		if love.filesystem.getInfo(mod.path .. "/config.json", 'file') then
			local modConfig = dpf.loadJson(mod.path .. "/config.json")
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
				log("Mod " .. mod.id .. " has invalid icon size. Mod icons must be 73x33.","BBP")
			else
				rawset(mod, "icon", modIcon)
			end
		end

		loader.mods[mod.id] = mod
		log("Registered mod '" .. mod.name .. "' by " .. mod.author .. ".","BBP_silent")

		if not mod.enabled then
			goto continue
		end

		-- load assets
		local assetsPath = mod.path .. "/assets"
		if love.filesystem.getInfo(assetsPath, 'directory') then
			-- load sprites
			bbp.utils.loopFiles(sprites, assetsPath .. "/textures", function(tbl, path, fileName)
				log("injecting sprite " .. path .. "...","BBP_silent")
				tbl[fileName] = love.graphics.newImage(path)
			end)

			-- load sounds
			bbp.utils.loopFiles(sounds, assetsPath .. "/sounds", function(tbl, path, fileName)
				log("injecting sound " .. path .. "...","BBP_silent")
				tbl[fileName] = love.sound.newSoundData(path)
			end)

			-- load shaders
			bbp.utils.loopFiles(shaders, assetsPath .. "/shaders", function(tbl, path, fileName)
				log("injecting shader " .. path .. "...","BBP_silent")
				tbl[fileName] = love.graphics.newShader(path)
			end)

			-- load animations
			bbp.utils.loopFiles(animations, assetsPath .. "/animations", function(tbl, path, fileName)
				if path:endswith(".png") then
					log("injecting animation " .. path .. "...","BBP_silent")
					local data = bbp.utils.getFileParent(path) .. "data.json"
					if not love.filesystem.getInfo(data, 'file') then
						log("Error while injecting animation '" .. path .. "'. The '" .. data .. "' file is missing!","BBP")
					end
					tbl[fileName] = ez.newjson(path, data)
				end
			end)

			-- load lang files
			bbp.utils.loopFiles(loc.json, assetsPath .. "/lang", function(tbl, path, fileName)
				table.insert(customLanguages, fileName)
				-- make sure we don't load english lang when owo is selected
				if fileName == savedata.options.language then
					log("injecting lang file " .. path .. "...","BBP_silent")
					local modLoc = dpf.loadJson(path, {})
					mergeLangFiles(loc.json, modLoc)
				end
			end)
		end

		-- load states
		bbp.utils.loopFiles({}, mod.path .. "/states", function(_, path, fileName)
			log("injecting state " .. path .. "...","BBP_silent")
			bs.fromPath(fileName, path)
			if bs.states[fileName] then
				setModChunkEnvironment(bs.states[fileName], mod)
			else
				log("failed to inject state " .. path,"BBP")
			end
		end)

		-- load entities
		bbp.utils.loopFiles({}, mod.path .. "/entities", function(_, path, fileName)
			log("injecting entity " .. path .. "...","BBP_silent")
			local chunk = love.filesystem.load(path)
			if chunk then
				em.entities[fileName] = setModChunkEnvironment(chunk, mod)()
			else
				log("failed to inject entity " .. path,"BBP")
			end
		end)

		-- load and call main.lua
		if love.filesystem.getInfo(mod.path .. "/main.lua") then
			local chunk, errormsg = love.filesystem.load(mod.path .. "/main.lua")
			if errormsg then
				log("Error while loading the main.lua file of '" .. mod.id .. "': " .. errormsg,"BBP")
			else
				setModChunkEnvironment(chunk, mod, true)()
			end
		end
		::continue::
	end

	log("Finished loading all mods! :D","BBP")

	if log.display.BBP_silent > 0 then
		bbp.utils.printTable(animations, "Animations:")
		bbp.utils.printTable(sprites, "Sprites:")
		bbp.utils.printTable(sounds, "Sounds:")
		bbp.utils.printTable(shaders, "Shaders:")
	end
end

return loader
