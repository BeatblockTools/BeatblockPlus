local utils = {}

-- Prints a table
function utils.printTable(table, title, indent)
	if title then
		print(title)
	end
	indent = indent or 0
	local indentStr = string.rep("  ", indent)

	for k, v in pairs(table) do
		if type(v) == "table" then
			print(indentStr .. tostring(k) .. ":")
			utils.printTable(v, nil, indent + 1)
		else
			print(indentStr .. tostring(k) .. ": " .. tostring(v))
		end
	end
end

-- Moves the source directory to the target directory, and deletes the source directory
function utils.moveDirectory(source, target)
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

-- Recursively loops all files in a directory and calls the callback function for each file.
-- This is used in BB+ for injecting assets, example usage:
--
-- loopFiles(sprites, assetsPath .. "/textures", function(tbl, path, fileName)
--   print("[BB+] injecting sprite " .. path .. "...")
-- 	 tbl[fileName] = love.graphics.newImage(path) <--- tbl refers to the 'sprites' table
-- end)
--
-- If you don't need a table, you can pass an empty table, for example:
--
-- loopFiles({}, mod.path .. "/states", function(_, path, fileName)
-- 	 print("[BB+] injecting state " .. path .. "...")
-- 	 bs.fromPath(fileName, path)
-- 	 if bs.states[fileName] then
--     setModChunkEnvironment(bs.states[fileName], mod)
--   end
-- end)
--
function utils.loopFiles(table, dir, callback)
	local function recurse(currentTable, currentDir)
		for _, item in ipairs(love.filesystem.getDirectoryItems(currentDir)) do
			local fullPath = currentDir .. "/" .. item
			if love.filesystem.getInfo(fullPath, "directory") then
				currentTable[item] = currentTable[item] or {}
				recurse(currentTable[item], fullPath)
			else
				local fileName = utils.extractFileName(item)
				callback(currentTable, fullPath, fileName)
			end
		end
	end

	recurse(table, dir)
end

-- Extracts the file name from a file path without the directory and extension
function utils.extractFileName(path)
	return path:match("([^/]+)$"):gsub("%..+$", "")
end

-- Gets the parent of a file
-- Example: assets/icon.png ---> assets/
function utils.getFileParent(fullPath)
	return fullPath:match("(.*/)") or "."
end

-- Checks if a string ends with another string
function string:endsWith(ending)
	return ending == "" or self:sub(- #ending) == ending
end

-- Gets a list of all mod names, their versions and authors
function utils.getModList()
	if not (bbp and bbp.mods) or next(bbp.mods) == nil then
		return "  Game crashed before mods could load"
	end

	local modList = {}

	for _, mod in pairs(bbp.mods) do
		table.insert(modList, "  - " .. mod.name .. " (" .. mod.version .. ") by " .. mod.author)
	end

	return table.concat(modList, "\n")
end

-- Finds all lovely injector warning messages in the most recent log file
function utils.getLovelyInjectorWarnings()
	local lovelyLogsPath = "Mods/lovely/log"

	-- get the newest log file
	local logPath = nil
	local newestTime = 0
	for _, item in ipairs(love.filesystem.getDirectoryItems(lovelyLogsPath)) do
		if item:match("%.log$") then
			local path = lovelyLogsPath .. "/" .. item
			local info = love.filesystem.getInfo(path)
			
			if info and info.modtime > newestTime then
				newestTime = info.modtime
				logPath = path
			end
		end
	end

	local warnList = {}

	if logPath then
		local content = love.filesystem.read(logPath)
		for line in content:gmatch("[^\r\n]+") do
			-- lovely warnings sometimes accidentally break up into two lines and this combines them again
			local warning, count = line:gsub("^WARN %- %[♥%] ' on target '", "", 1)
			if count > 0 and #warnList > 0 then
				warnList[#warnList] = warnList[#warnList].."' on target '"..warning
			else
				-- regular warnings
				local warning, count = line:gsub("^WARN %- %[♥%]", "", 1)
				if count > 0 then
					table.insert(warnList, "  -"..warning)
				end
			end
		end
	else
		return "  log file not found"
	end

	if #warnList == 0 then
		return "  no warnings found in the log file"
	end

	return table.concat(warnList, "\n")
end

-- Checks if a table contains a value, does NOT check for nested values
function utils.tableContains(table, value)
	for i = 1, #table do
		if (table[i] == value) then
			return true
		end
	end

	return false
end

return utils
