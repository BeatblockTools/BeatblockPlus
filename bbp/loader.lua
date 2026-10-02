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

function loader.setModEnabled(mod, enabled)
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

function loader.deleteOldLogs()
	if not mods then
		log("mods table not found. no logs deleted","BBP")
		return
	end

	log("deleting old log files...", "BBP_silent")

	local start = love.timer.getTime()
	local deletedCount = 0

	local function deleteHere(path, keep)
		local files = {}
		for i, item in ipairs(love.filesystem.getDirectoryItems(path)) do
			local fullPath = path.."/"..item
			local info = love.filesystem.getInfo(fullPath)
			if info.type == "file" and info.modtime then
				files[i] = {fullPath = fullPath, modtime = info.modtime}
			end
		end
		table.sort(files, function(a, b)
			return a.modtime > b.modtime
		end)
		for i, file in ipairs(files) do
			if i > keep then
				love.filesystem.remove(file.fullPath)
				log("deleted "..file.fullPath,"BBP_silent")
				deletedCount = deletedCount +1
			end
		end
	end

	local config = mods["beatblock-plus"].config

	if config.delete.crashreports then
		deleteHere("crashreports", config.keep.crashreports)
	end

	if config.delete.logs then
		deleteHere("logs", config.keep.logs)
	end

	if config.delete.lovelylog then
		deleteHere("Mods/lovely/log", config.keep.lovelylog)
	end

	local duration = love.timer.getTime() - start
	log("took "..duration.." seconds to delete "..deletedCount.." old log files", "BBP_silent")
end

function loader.loadModMetadata(modDir)
	if not love.filesystem.getInfo(modDir .. "/mod.json", "file") then return end
	local modJson = dpf.loadJson(modDir .. "/mod.json")

	local mod = {
		path = modDir,
		id = assert(modJson.id, ("'%s/mod.json': missing mandatory field 'id'"):format(modDir)),
		name = modJson.name or modJson.id,
		author = modJson.author or "Unknown",
		description = modJson.description or "",
		version = modJson.version or "1.0.0",
		icon = nil,
		defaultConfig = modJson.config or {},
		config = helpers.copytable(modJson.config or {}),
		depends = modJson.depends or {},
		conflicts = modJson.conflicts or {},
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
				return loader.setModEnabled(t, v)
			end
			error(("Attmepted to create new field '%s' on mod"):format(k))
		end
	})
	mod.enabled = love.filesystem.getInfo(mod.path .. "/.lovelyignore", 'file') == nil
	if modJson.enabled ~= nil then log("'" .. modDir .. "/mod.json': 'enabled' is deprecated in favor of the .lovelyignore file","BBP") end

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
		assert(width == 73 and height == 33, ("Mod icon '%s' has invalid size. Mod icons must be 73x33."):format(mod.path.."/icon.png"))
		rawset(mod, "icon", modIcon)
	end

	return mod
end

local function checkVersion(ver, versions) -- check if `ver` is covered by `versions`
	if versions == nil then
		return true
	end

	local function splitVersion(v)
		local r = {}
		for n in string.gmatch(v, "([^.]+)%.?") do
			table.insert(r, tonumber(n:match("%d+")))
		end
		if #r == 0 then log("could not split version: "..v ,"BBP") end
		return r
	end

	local function compare(v1, v2, func, last) -- func should return true, false or nil
		v1 = type(v1) == "table" and v1 or splitVersion(v1)
		v2 = type(v2) == "table" and v2 or splitVersion(v2)
		for i=1,math.max(#v1,#v2) do
			local c = func(v1[i] or 0, v2[i] or 0)
			if c ~= nil then return c end
		end
		return last
	end

	local function eq(v1, v2) return compare(v1, v2, function(a, b) if a == b then return nil else return false end end, true) end
	local function lt(v1, v2) return compare(v1, v2, function(a, b) if a == b then return nil else return a < b end end, false) end
	local function gt(v1, v2) return compare(v1, v2, function(a, b) if a == b then return nil else return a > b end end, false) end

	assert(type(versions) == "string", "version specifier must be a string!")

	if versions:startsWith("=") then
		local ver2 = versions:sub(2)
		return eq(ver, ver2)
	elseif versions:startsWith("<=") then
		local ver2 = versions:sub(3)
		return not gt(ver, ver2)
	elseif versions:startsWith(">=") then
		local ver2 = versions:sub(3)
		return not lt(ver, ver2)
	elseif versions:startsWith("<") then
		local ver2 = versions:sub(2)
		return lt(ver, ver2)
	elseif versions:startsWith(">") then
		local ver2 = versions:sub(2)
		return gt(ver, ver2)
	end

	error(("Invalid version specifier '%s'"):format(versions))
end

local function checkModDependsConflicts(mod)
	local problems = {}

	for id,version in pairs(mod.depends) do
		local mentionedMod = loader.mods[id]
		local dep_problem = "'" .. mod.id .. "' is missing dependency "
		if not mentionedMod then
			table.insert(problems, (dep_problem.."'%s': not installed"):format(id))
		elseif not mentionedMod.enabled then
			table.insert(problems, (dep_problem.."'%s': not enabled"):format(id))
		elseif version ~= "" and not checkVersion(mentionedMod.version, version) then
			table.insert(problems, (dep_problem.."'%s': wrong version (%s), expected '%s'"):format(id, mentionedMod.version, version))
		end
	end

	for id,version in pairs(mod.conflicts) do
		local mentionedMod = loader.mods[id]
		if mentionedMod and mentionedMod.enabled then
			if version == "" then
				table.insert(problems, ("'%s' is incompatible with '%s'"):format(mod.id, id))
			elseif checkVersion(mentionedMod.version, version) then
				table.insert(problems, ("'%s' is incompatible with '%s' version '%s'"):format(mod.id, id, version))
			end
		end
	end

	return problems
end

-- returns a (multiline) string with problems, or nil
function loader.checkDependsConflicts()
	local problems = {}
	for id,mod in pairs(loader.mods) do
		if not mod.enabled then goto continue end

		local p = checkModDependsConflicts(mod)
		if #p > 0 then
			table.insert(problems, table.concat(p, "\n"))
		end

		::continue::
	end
	if #problems == 0 then
		return nil
	end
	return table.concat(problems, "\n\n")
end

function loader.loadMods() -- loads mod data, assets, mod icons etc.
	loader.mods = {}
	loader.activeMods = {}

	-- TODO: remove this later due to deprecation
	mods = loader.mods

	local modsPath = "Mods"
	local success = love.filesystem.getInfo(modsPath, 'directory')

	if not success then
		error("BBP failed to find the Mods directory.")
		return
	end

	for _, modDir in ipairs(love.filesystem.getDirectoryItems(modsPath)) do
		local mod = loader.loadModMetadata(modsPath.."/"..modDir)
		if not mod then goto continue end

		loader.activeMods[mod.id] = mod.enabled or nil -- not including disabled mods
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
				if path:endsWith(".png") then
					log("injecting animation " .. path .. "...","BBP_silent")
					local data = bbp.utils.getFileParent(path) .. bbp.utils.extractFileName(path) .. ".json"
					if not love.filesystem.getInfo(data, 'file') then
						error("Error while injecting animation '" .. path .. "'. " .. bbp.utils.extractFileName(path) .. ".json is missing!")
					else
						tbl[fileName] = ez.newjson(path, data)
					end
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

	local problems = loader.checkDependsConflicts()
	if problems then
		print("Incompatible mods!\n"..problems)

		local buttons = {
			"Exit",
			"Continue anyway",
			"Open mod menu",
			escapebutton = 1,
			enterbutton = 3,
		}
		local pressed = love.window.showMessageBox("Incompatible mods!", problems.."\n\nWe recommend resolving these issues in the mod menu before continuing.", buttons, "error", false)
		if pressed == 1 then
			love.event.quit()
		elseif pressed == 2 then
			-- do nothing
		else
			project.initState = 'Mods'
		end
	end

	if log.display.BBP_silent > 0 then
		bbp.utils.printTable(animations, "Animations:")
		bbp.utils.printTable(sprites, "Sprites:")
		bbp.utils.printTable(sounds, "Sounds:")
		bbp.utils.printTable(shaders, "Shaders:")
	end
end

return loader
