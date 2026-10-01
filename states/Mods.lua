local st = Gamestate:new('Mods')

-- used to automatically render a config if the mod doesn't have a config.lua file
local function generateConfig(config)
	for k, v in pairs(config) do
		if type(v) == "table" then
			imgui.Separator()
			imgui.TextWrapped(k)
			generateConfig(v)
			imgui.Separator()
		elseif type(v) == "number" then
			config[k] = helpers.InputFloat(k, v)
		elseif type(v) == "string" then
			config[k] = helpers.InputText(k, v)
		elseif type(v) == "boolean" then
			config[k] = helpers.InputBool(k, v)
		end
	end
end

-- I'm so sorry for using a string for control flow, but it's the best solution I could find.
local nextPopupTitle = ""
local nextPopupData = {}

local function openPopup(title, data)
	nextPopupTitle = title
	nextPopupData = data or {}
end

local function openPopupNextFrame(self, title, data)
	-- opening a popup from within another popup has to be delayed to the next frame
	self.nextPopupTitle = title
	self.nextPopupData = data or {}
end

local function renderModConfig(self, mod)
	if mod.notSelectable then
		self.selectedModId = "beatblock-plus"
		return
	end

	imgui.TextWrapped(mod.name .. " (" .. mod.version .. ") by " .. mod.author)
	imgui.TextWrapped(mod.description)
	imgui.Separator()

	-- toggle for the mod
	if mod.id ~= "beatblock-plus" then
		mod.enabled = helpers.InputBool("Enabled (Requires Restart)", mod.enabled)
	end

	if imgui.Button("Reset Config to Default") then
		openPopup("reset config confirmation", {name = mod.name, path = mod.path, id = mod.id})
	end

	if mod.id ~= "beatblock-plus" then
		imgui.SameLine()
		if imgui.Button("Delete Mod") then
			openPopup("delete mod confirmation", {name = mod.name, path = mod.path, id = mod.id})
		end
	end

	if imgui.Button("Save Changes") then
		self.savedConfigDisplayTimer = love.timer.getTime()
		bbp.utils.saveConfig(mod.id)
	end

	-- display some text next to the button for one second, so that the user knows that it worked
	if self.savedConfigDisplayTimer then
		if love.timer.getTime() - self.savedConfigDisplayTimer > 1 then
			self.savedConfigDisplayTimer = nil --one second is over
		else
			imgui.SameLine()
			imgui.Text("Saved!")
		end
	end

	imgui.Separator()

	-- if the mod has a config.lua file, use that to render the config gui
	-- else generate it automatically
	if mod.configRenderer then
		mod.configRenderer()
	else
		generateConfig(mod.config)
	end
end

local function countMods()
	return bbp.utils.countTable(bbp.mods)
end

local function countEnabledMods()
	local count = 0
	for _, mod in pairs(bbp.mods) do
		if mod.enabled then count = count + 1 end
	end
	return count
end

local function modListChanged()
	for _, mod in pairs(bbp.mods) do
		-- convert to boolean because bbp.loader.activeMods is either true or nil
		if mod.enabled ~= (bbp.loader.activeMods[mod.id] or false) then
			return true
		end
	end
	return false
end

st.loadMainMenu = function(self)
	cs = bs.load('Menu')
	if self.menuMusicManager then self.menuMusicManager:clearOnBeatHooks() end
	cs.menuMusicManager = self.menuMusicManager
	cs:init()

	-- return to ingame cursor if the settings say so
	if savedata.options.game.customCursorInMenu and (savedata.options.game.cursorMode ~= "default") then
		love.mouse.setVisible(false)
	end
end

function st:tryExit()
	if self._restartRequired then
		maininput:update()
		openPopup("quit with restart required")
		return
	end
	if modListChanged() then
		maininput:update()
		openPopup("quit with changed mod list")
		return
	end
	local problems = bbp.loader.checkDependsConflicts()
	if problems then
		maininput:update()
		openPopup("incompatible mods", {problems = problems})
	end

	self:loadMainMenu()
end

-- generate cs.sortedIDs from global mods
local function getSortedIDs()
	cs.sortedIDs = {}
	local i = 0
	for modID, _ in pairs(mods) do
		i = i + 1
		cs.sortedIDs[i] = modID
	end
	-- the list contains ids, but they're sorted by name
	table.sort(cs.sortedIDs, function(a, b)
		return mods[a].name:lower() < mods[b].name:lower()
	end)
end

-- load mod as an unselectable item for the mod boxes
local function loadUnselectableMod(modDir)
	local mod = bbp.loader.loadModMetadata(modDir)
	rawset(mod, "notSelectable", true)
	return mod
end

-- look for mod.json and return parent folder path and mod.json data
local function findModFolder(currentDir)
	for _, item in ipairs(love.filesystem.getDirectoryItems(currentDir)) do
		local itemDir = currentDir .. "/" .. item
		if love.filesystem.getInfo(itemDir, "directory") then
			local modFolder, modData = findModFolder(itemDir)
			if modFolder then
				return modFolder, modData
			end
		elseif item == "mod.json" then
			return currentDir, dpf.loadJson(itemDir)
		end
	end
end

local function handleDroppedMod(path)
	if love.filesystem.mount(path, "draganddrop") then
		local mountedModFolder, modData = findModFolder("draganddrop")

		if not mountedModFolder then
			log("Error: couldn't find mod.json in " .. path, "BBP")
			openPopup("error: no mod.json found")
			love.filesystem.unmount(path)
			return
		end

		local fullPath = "Mods/"..modData.id

		if love.filesystem.getInfo(fullPath) then
			openPopup("update confirmation", {path=path,modData=modData,mountedModFolder=mountedModFolder})
			love.filesystem.unmount(path)
			return
		end

		love.filesystem.createDirectory(fullPath)
		helpers.recursiveFolderCopy(fullPath, mountedModFolder)
		love.filesystem.unmount(path)

		openPopup("new mod added", modData)
		mods[modData.id] = loadUnselectableMod(fullPath)
		getSortedIDs()
	else
		-- I think this only happens if someone drags a completely empty zip into the game.
		log("Error: didn't mount draganddrop directory", "BBP")
		return
	end
end

function st:directorydropped(path)
	handleDroppedMod(path)
end

function st:filedropped(file)
	local path = file:getFilename()
	if string.sub(path, -4, -1) ~= ".zip" then
		log("Error: not a valid zip file: " .. path, "BBP")
		openPopup("error: invalid file type dropped")
		return
	end
	handleDroppedMod(path)
end

st:setInit(function(self)
	love.keyboard.setTextInput(true)

	self.selectedModId = "beatblock-plus"

	getSortedIDs()

	-- ingame cursor doesn't work in the mod menu, so we always use the regular one
	love.mouse.setVisible(true)
end)

st:setUpdate(function(self, dt)
	if maininput:pressed("r") then
		-- clear config renderer cache
		rawset(bbp.mods[self.selectedModId], '_configRenderer', nil)
	elseif maininput:pressed("back") then
		self:tryExit()
	end
end)

st:setBgDraw(function(self)
	color()
	love.graphics.rectangle('fill', 0, 0, 600, 360)
end)

st:setFgDraw(function(self)
	local windowWidth = imgui.canvasScale and (project.res.x * imgui.canvasScale) or love.graphics.getWidth()
	local windowHeight = imgui.canvasScale and (project.res.y * imgui.canvasScale) or love.graphics.getHeight()

	helpers.SetNextWindowPos(0, 0)
	helpers.SetNextWindowSize(windowWidth, windowHeight)
	--												423
	local appliedBBPTheme = false -- The following config may change mid draw call
	if mod.config.lightMode then
		bbp.gui.pushStyle()
		appliedBBPTheme = true
	end
	imgui.Begin("Mods", true, 295) -- notitlebar, noresize, nomove, nocollapse, nobackground, nosavedsettings

	imgui.SetWindowFontScale(2)
	imgui.Text("Mods: " .. tostring(countEnabledMods()) .. " / " .. tostring(countMods()))
	imgui.SameLine(200)
	imgui.Text("To install a mod, drag and drop the zip file into this menu.")
	imgui.SetWindowFontScale(1)
	imgui.Separator()

	imgui.BeginChild_Str("mod_list_and_config", imgui.ImVec2_Float(windowWidth -20, windowHeight - 90), 0)

	imgui.Columns(2, "main", true)
	imgui.SetColumnWidth(imgui.GetColumnIndex(), windowWidth * 0.6)

	-- start drawing mod boxes
	imgui.BeginChild_Str("mod_list", imgui.ImVec2_Float(550 / 600 * windowWidth, windowHeight - 90), 0)

	for _, modID in pairs(self.sortedIDs) do
		local mod = bbp.mods[modID]
		local childWidth = windowWidth * 0.59
		local childHeight = 42 * 2 -- just enough to fit the mod icon
		imgui.BeginChild_Str("mod_" .. mod.id, imgui.ImVec2_Float(childWidth, childHeight), 1)

		imgui.Columns(2, "mod_details_" .. mod.id, true)

		-- mod icon
		local modIcon = mod.icon or sprites.bbp.missing
		if modIcon then
			imgui.SetColumnWidth(imgui.GetColumnIndex(), 82 * 2)
			local imageSizeX = 73 * 2
			local imageSizeY = 33 * 2
			imgui.Image(modIcon, imgui.ImVec2_Float(imageSizeX, imageSizeY))
			imgui.NextColumn()
		end

		-- mod details (name, icon, version, etc.)
		imgui.SetColumnWidth(imgui.GetColumnIndex(), childWidth)
		imgui.Text(mod.name .. " by " .. mod.author .. " (" .. mod.version .. ")")
		
		-- for mods that were just updated or deleted
		if mod.notSelectable then
			imgui.SameLine()
			imgui.Text("[please restart]")
		end
		
		imgui.TextWrapped(mod.description)

		-- show config when clicked
		if imgui.IsWindowHovered() and imgui.IsMouseClicked(0) and not mod.notSelectable then -- left click
			self.selectedModId = mod.id
		end

		imgui.EndChild() -- end mod box
	end

	imgui.EndChild() -- end mod list

	imgui.NextColumn()
	imgui.SetColumnWidth(imgui.GetColumnIndex(), windowWidth * 0.39)

	-- start a new child for config because imgui likes to break everything otherwise
	imgui.BeginChild_Str("mod_config_" .. self.selectedModId, imgui.ImVec2_Float(0, 0), false)
	renderModConfig(self, bbp.mods[self.selectedModId])
	imgui.EndChild()

	imgui.EndChild() -- end mod list and config
	imgui.Separator()

	if imgui.Button("Go Back") then
		self:tryExit()
	end

	imgui.SameLine()

	if imgui.Button("Restart Game") then
		openPopup("restart game confirmation")
	end

	imgui.SameLine()

	if imgui.Button("Open Mods Folder") then
		love.system.openURL("file://" .. love.filesystem.getSaveDirectory() .. '/Mods')
	end

	--popups

	local popupFlags = bit.bor(
			imgui.ImGuiWindowFlags_AlwaysAutoResize,
			imgui.ImGuiWindowFlags_NoResize,
			imgui.ImGuiWindowFlags_NoMove,
			imgui.ImGuiWindowFlags_NoSavedSettings,
			imgui.ImGuiWindowFlags_NoTitleBar
		)

	local function popupBody(text)
		if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
			imgui.CloseCurrentPopup()
		end

		imgui.Text(text)

		imgui.Separator()
		if imgui.Button("OK") then
			imgui.CloseCurrentPopup()
		end

		imgui.SetItemDefaultFocus()
	end

	-- popup event carried over from previous frame
	if self.nextPopupTitle then
		nextPopupTitle = self.nextPopupTitle
		self.nextPopupTitle = nil
	end

	-- display the newly triggered popup
	if nextPopupTitle ~= "" then
		imgui.OpenPopup_Str(nextPopupTitle)
		nextPopupTitle = ""
		te.playOne(sounds.barely,"static",'sfx',1.5)
	end

	-- copy local data into state data
	self.popupData = nextPopupData or self.popupData

	if imgui.BeginPopupModal("error: invalid file type dropped", nil, popupFlags) then
		popupBody("Could not identify the dropped file type. Make sure you're using a .zip file.\nNo mod was added.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("error: no mod.json found", nil, popupFlags) then
		popupBody("The zip file doesn't have a mod.json where we expected one to be.\n"..
				"Make sure that your file has the following structure: modFile.zip/folder-name/mod.json\n"..
				"No mod was added.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("error: mod already exists", nil, popupFlags) then
		popupBody("A mod with the folder name '"..self.popupData.modFolder.."' is already present.\n"..
				"If you're trying to update, please remove the previous version from your Mods directory.\n"..
				"No mod was added.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("update confirmation", nil, popupFlags) then
		if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
			imgui.CloseCurrentPopup()
		end

		local modData = self.popupData.modData

		imgui.Text("Are you sure, you want to update '" .. modData.name .. "' from " .. mods[modData.id].version ..
				" to " .. modData.version .. " ?\nMod path: Mods/" .. modData.id ..
				"\nYour configs will be carried over. !! THIS CAN'T BE UNDONE !!")

		imgui.Separator()

		if imgui.Button("Yes") then
			local success = love.filesystem.mount(self.popupData.path, "draganddrop")
			if not success then error("failed to mount previously valid directory. maybe it was moved?") end

			local fullPath = "Mods/"..modData.id
			bbp.utils.deleteDirectory(fullPath)
			love.filesystem.createDirectory(fullPath)
			helpers.recursiveFolderCopy(fullPath, self.popupData.mountedModFolder)

			love.filesystem.unmount(self.popupData.path)

			local userconfig = helpers.copytable(modData.config)
			for k,v in pairs(mods[modData.id].config) do
				userconfig[k] = v
			end
			dpf.saveJson(fullPath .. "/config.json", userconfig)
			bbp.loader.setModEnabled(mods[modData.id], mods[modData.id]._enabled)

			bbp.utils.setRestartRequired()
			mods[modData.id] = loadUnselectableMod("Mods/"..modData.id)

			openPopupNextFrame(self, "successfully updated mod", self.popupData)
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		imgui.SetItemDefaultFocus()
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("successfully updated mod", nil, popupFlags) then
		local modData = self.popupData.modData
		popupBody("The following mod has been updated: " ..
				modData.name .. " (" .. modData.version .. ") by " .. modData.author
				.."\nPlease restart the game.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("new mod added", nil, popupFlags) then
		popupBody("The following mod has been added successfully: " ..
				self.popupData.name .. " (" .. self.popupData.version .. ") by " .. self.popupData.author
				.."\nRestart the game for the mod to take effect.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("reset config confirmation", nil, popupFlags) then
		if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
			imgui.CloseCurrentPopup()
		end

		imgui.Text("Are you sure, you want to reset the config of '" .. self.popupData.name .. "' ?\n!! THIS CAN'T BE UNDONE !!")

		imgui.Separator()

		if imgui.Button("Yes") then
			self.popupData.configPath = self.popupData.path .. "/config.json"

			if not love.filesystem.getInfo(self.popupData.configPath) then
				openPopupNextFrame(self, "error: no config.json found", self.popupData)
			end

			dpf.saveJson(self.popupData.configPath, mod.config)

			local success = love.filesystem.remove(self.popupData.configPath)
			if success then
				bbp.mods[self.popupData.id].config = helpers.copy(bbp.mods[self.popupData.id].defaultConfig)
				openPopupNextFrame(self, "successfully reset config", self.popupData)
			else
				openPopupNextFrame(self, "error: failed to delete config.json", self.popupData)
			end
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		imgui.SetItemDefaultFocus()
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("error: no config.json found", nil, popupFlags) then
		popupBody("No config file found at: " .. self.popupData.configPath)
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("successfully reset config", nil, popupFlags) then
		popupBody("Config of '" .. self.popupData.name .. "' has been set to default.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("error: failed to delete config.json", nil, popupFlags) then
		popupBody("Failed to delete config file: " .. self.popupData.configPath .."\n"..
				"Make sure that you don't have the file open in another program.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("delete mod confirmation", nil, popupFlags) then
		if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
			imgui.CloseCurrentPopup()
		end

		imgui.Text("Are you sure, you want to delete '" .. self.popupData.name .. "' ?\n"..
				"Mod path: " .. self.popupData.path .. "\n!! THIS CAN'T BE UNDONE !!")

		imgui.Separator()

		if imgui.Button("Yes") then
			bbp.utils.deleteDirectory(self.popupData.path)
			if not love.filesystem.getInfo(self.popupData.path) then
				bbp.utils.setRestartRequired()
				rawset(mods[self.popupData.id], "notSelectable", true)
				openPopupNextFrame(self, "successfully deleted mod", self.popupData)
			else
				openPopupNextFrame(self, "error: failed to delete mod", self.popupData)
			end
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		imgui.SetItemDefaultFocus()
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("successfully deleted mod", nil, popupFlags) then
		popupBody("The mod '" .. self.popupData.name .. "' has been deleted.\nPlease restart the game.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("error: failed to delete mod", nil, popupFlags) then
		popupBody("Failed to delete mod folder: " .. self.popupData.path .."\n"..
				"Make sure that you don't have any files from the folder open in another program.")
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("restart game confirmation", nil, popupFlags) then
		if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
			imgui.CloseCurrentPopup()
		end

		imgui.Text("Are you sure, you want to restart the game?")

		imgui.Separator()

		if imgui.Button("Yes") then
			bbp.utils.restart()
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		imgui.SetItemDefaultFocus()
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("quit with restart required", nil, popupFlags) then
		if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
			imgui.CloseCurrentPopup()
		end

		imgui.Text("You have made some changes that require a restart.\nPlease restart the game.")

		imgui.Separator()

		if imgui.Button("Yes, restart now") then
			bbp.utils.restart()
		end

		imgui.SameLine()
		if imgui.Button("No, return to mod menu") then
			imgui.CloseCurrentPopup()
		end

		imgui.SetItemDefaultFocus()
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("quit with changed mod list", nil, popupFlags) then
		if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
			imgui.CloseCurrentPopup()
		end

		imgui.Text("You have enabled/disabled some of your mods.\nPlease restart the game, or revert these changes.")

		imgui.Separator()

		if imgui.Button("Yes, restart now") then
			bbp.utils.restart()
		end

		imgui.SameLine()
		if imgui.Button("No, return to mod menu") then
			imgui.CloseCurrentPopup()
		end

		imgui.SetItemDefaultFocus()
		imgui.EndPopup()
	end

	if imgui.BeginPopupModal("incompatible mods", nil, popupFlags) then
		imgui.TextUnformatted("You have incompatible mods!\n" .. self.popupData.problems)
		imgui.Separator()

		if imgui.Button("Return to mod menu") then
			imgui.CloseCurrentPopup()
		end
		imgui.SetItemDefaultFocus()

		imgui.SameLine()
		if imgui.Button("Continue anyway (don't do this!)") then
			imgui.CloseCurrentPopup()
			st:loadMainMenu()
		end

		imgui.SameLine()
		if imgui.Button("Close beatblock") then
			love.event.quit()
		end

		imgui.EndPopup()
	end

	imgui.End()
	if appliedBBPTheme then
		bbp.gui.popStyle()
	end
end)

return st
