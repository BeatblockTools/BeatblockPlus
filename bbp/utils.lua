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
function utils.getModNames()
	local modNames = {}

	for _, mod in pairs(bbp.mods) do
		table.insert(modNames, "  - " .. mod.name .. " (" .. mod.version .. ") by " .. mod.author)
	end

	return table.concat(modNames, "\n")
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
