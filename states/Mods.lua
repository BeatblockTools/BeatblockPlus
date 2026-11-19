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

-- open a popup next frame
local function openPopup(title,data)
	cs.nextPopupTitle = title
	cs.popupData = data or {}
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
		openPopup("input: reset config", {name = mod.name, path = mod.path, id = mod.id})
	end

	if mod.id ~= "beatblock-plus" then
		imgui.SameLine()
		if imgui.Button("Delete Mod") then
			openPopup("input: delete mod", {name = mod.name, path = mod.path, id = mod.id})
		end
	end

	if imgui.Button("Save Changes") then
		self.savedConfigDisplayTimer = love.timer.getTime()
		bbp.utils.saveConfig(mod.id)
	end

	-- display some text next to the button for one second, so that the user knows that it worked
	if self.savedConfigDisplayTimer then
		if love.timer.getTime() - self.savedConfigDisplayTimer > 1 then
			self.savedConfigDisplayTimer = nil -- one second is over
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
		openPopup("input: quit with restart required")
		return
	end
	if modListChanged() then
		maininput:update()
		openPopup("input: quit with changed mod list")
		return
	end
	local problems = bbp.loader.checkDependsConflicts()
	if problems then
		maininput:update()
		openPopup("input: incompatible mods", { problems = problems })
		return
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
	assert(mod, "failed to load mod metadata from path "..modDir)
	rawset(mod, "notSelectable", true)
	return mod
end

function st:try_install_mod(actions)
	actions = actions or {}

	if self.installable_mod.droppedPath:match("Roaming\\beatblock\\Mods") then
		openPopup("info: cant install mod from Mods folder")
		return
	end

	local modData = self.installable_mod.modData
	if actions.check_incompatibility then
		local problems = bbp.loader.checkModDependsConflicts(modData)
		if #problems > 0 then
			openPopup("input: new mod incompatible", { modData = modData , problems = table.concat(problems, "\n") })
			return
		end
	end

	if actions.check_for_update then
		if mods[modData.id] then
			openPopup("input: update mod", { modData = modData })
			return
		end
	end

	local success = love.filesystem.mount(self.installable_mod.droppedPath, "draganddrop")
	if not success then
		openPopup("error: failed to mount", { path = self.installable_mod.droppedPath })
		return
	end

	local modPath
	if mods[modData.id] then
		modPath = mods[modData.id].path
	else
		modPath = "Mods/" .. modData.id
	end

	if actions.update then
		-- configs will be recoverable in the crashlog if something goes wrong
		self.config_temp_copy = helpers.copytable(mods[modData.id].config)

		bbp.utils.deleteDirectory(modPath)
	end

	-- no more conflicts. clean install now
	love.filesystem.createDirectory(modPath)
	helpers.recursiveFolderCopy(modPath, self.installable_mod.mountedPath)
	love.filesystem.unmount(self.installable_mod.droppedPath)

	if actions.update then
		dpf.saveJson(modPath .. "/config.json", self.config_temp_copy)
		self.config_temp_copy = nil
	end

	self.installable_mod = nil
	bbp.utils.setRestartRequired()

	mods[modData.id] = loadUnselectableMod(modPath)
	getSortedIDs()

	if actions.update then
		openPopup("info: successfully updated mod", self.popupData)
	else
		openPopup("info: new mod added", modData)
	end
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

function st:handleDroppedMod(path)
	print("dropped path:",path)
	if love.filesystem.mount(path, "draganddrop") then
		local mountedPath, modData = findModFolder("draganddrop")
		love.filesystem.unmount(path)

		if not mountedPath then
			log("Error: couldn't find mod.json in " .. path, "BBP")
			openPopup("error: no mod.json found")
			return
		end

		self.installable_mod = { droppedPath = path, modData = modData, mountedPath = mountedPath }
		self:try_install_mod({ check_incompatibility = true, check_for_update = true })
	else
		log("Error: didn't mount directory: " .. path, "BBP")
		return
	end
end

function st:directorydropped(path)
	self:handleDroppedMod(path)
end

function st:filedropped(file)
	local path = file:getFilename()
	if string.sub(path, -4, -1) ~= ".zip" then
		openPopup("error: invalid file type dropped")
		return
	end
	self:handleDroppedMod(path)
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
		imgui.SetColumnWidth(imgui.GetColumnIndex(), 82 * 2)
		local imageSizeX = 73 * 2
		local imageSizeY = 33 * 2
		imgui.Image(modIcon, imgui.ImVec2_Float(imageSizeX, imageSizeY))
		imgui.NextColumn()

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
		openPopup("input: restart game")
	end

	imgui.SameLine()

	if imgui.Button("Open Mods Folder") then
		love.system.openURL("file://" .. love.filesystem.getSaveDirectory() .. '/Mods')
	end

	--popups

	if self.nextPopupTitle then
		log("Info: opening popup '" .. self.nextPopupTitle .. "'", "BBP")
		imgui.OpenPopup_Str(self.nextPopupTitle)
		te.playOne(sounds.barely, "static", 'sfx', 1.5)
		self.nextPopupTitle = nil
	end

	local function beginPopup(title)
		local popupFlags = bit.bor(
			imgui.ImGuiWindowFlags_AlwaysAutoResize,
			imgui.ImGuiWindowFlags_NoResize,
			imgui.ImGuiWindowFlags_NoMove,
			imgui.ImGuiWindowFlags_NoSavedSettings,
			imgui.ImGuiWindowFlags_NoTitleBar
		)
		if imgui.BeginPopupModal(title, nil, popupFlags) then
			-- center the popup
			local popup_size = imgui.GetWindowSize()
			imgui.SetWindowPos_Vec2(imgui.ImVec2_Float(
				(windowWidth - popup_size.x) / 2,
				(windowHeight - popup_size.y) / 2
			))
			-- close on outside click
			if imgui.IsKeyChordPressed(655) and not imgui.IsWindowHovered() then
				imgui.CloseCurrentPopup()
			end

			return true
		end
		return false
	end

	local function defaultPopupBody(text)
		imgui.Text(text)
		imgui.Separator()
		if imgui.Button("OK") then
			imgui.CloseCurrentPopup()
		end
	end

	local function endPopup()
		imgui.SetItemDefaultFocus()
		imgui.EndPopup()
	end

	if beginPopup("error: invalid file type dropped") then
		defaultPopupBody("Could not identify the dropped file type. Make sure you're using a .zip file.\nNo mod was added.")
		endPopup()
	end

	if beginPopup("error: no mod.json found") then
		defaultPopupBody("The file doesn't contain a mod.json.\nNo mod was added.")
		endPopup()
	end

	if beginPopup("error: mod already exists") then
		defaultPopupBody("A mod with the folder name '" .. self.popupData.modFolder .. "' is already present.\n"..
				"If you're trying to update, please remove the previous version from your Mods directory.\n"..
				"No mod was added.")
		endPopup()
	end

	if beginPopup("error: failed to mount") then
		defaultPopupBody("Failed to mount previously valid directory:\n" .. self.popupData.path .. "\n\nMaybe it was moved?")
		endPopup()
	end

	if beginPopup("input: new mod incompatible") then
		local modData = self.popupData.modData

		imgui.TextUnformatted("The new mod will be incompatible with your current mod list!\n\n" .. self.popupData.problems ..
				"\n\nYou should resolve these issues before installing the mod.")

		imgui.Separator()

		if imgui.Button("Install anyway") then
			self:try_install_mod({ check_for_update = true })
		end

		imgui.SameLine()
		if imgui.Button("Cancel") then
			imgui.CloseCurrentPopup()
		end

		endPopup()
	end

	if beginPopup("info: cant install mod from Mods folder") then
		defaultPopupBody("The mod at path " .. self.installable_mod.droppedPath ..
				"\ncan't be installed, because it's in the Mods folder. Please move it somewhere else and then try again.")
		endPopup()
	end
	
	if beginPopup("input: update mod") then
		local modData = self.popupData.modData

		imgui.Text("Are you sure, you want to update '" .. modData.name .. "' from " .. mods[modData.id].version ..
				" to " .. modData.version .. " ?\nMod path: " .. mods[modData.id].path ..
				"\nYour configs will be carried over. !! THIS CAN'T BE UNDONE !!")

		imgui.Separator()

		if imgui.Button("Yes") then
			self:try_install_mod({ update = true })
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		endPopup()
	end

	if beginPopup("info: successfully updated mod") then
		local modData = self.popupData.modData
		defaultPopupBody("The following mod has been updated: " ..
				modData.name .. " (" .. modData.version .. ") by " .. modData.author
				.."\nPlease restart the game.")
		endPopup()
	end

	if beginPopup("info: new mod added") then
		defaultPopupBody("The following mod has been added successfully: " ..
				self.popupData.name .. " (" .. self.popupData.version .. ") by " .. self.popupData.author
				.."\nRestart the game for the mod to take effect.")
		endPopup()
	end

	if beginPopup("input: reset config") then

		imgui.Text("Are you sure, you want to reset the config of '" .. self.popupData.name .. "' ?\n!! THIS CAN'T BE UNDONE !!")

		imgui.Separator()

		if imgui.Button("Yes") then
			self.popupData.configPath = self.popupData.path .. "/config.json"

			if not love.filesystem.getInfo(self.popupData.configPath) then
				openPopup("error: no config.json found", self.popupData)
			end

			dpf.saveJson(self.popupData.configPath, mod.config)

			local success = love.filesystem.remove(self.popupData.configPath)
			if success then
				bbp.mods[self.popupData.id].config = helpers.copy(bbp.mods[self.popupData.id].defaultConfig)
				openPopup("info: successfully reset config", self.popupData)
			else
				openPopup("error: failed to delete config.json", self.popupData)
			end
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		endPopup()
	end

	if beginPopup("error: no config.json found") then
		defaultPopupBody("No config file found at: " .. self.popupData.configPath)
		endPopup()
	end

	if beginPopup("info: successfully reset config") then
		defaultPopupBody("Config of '" .. self.popupData.name .. "' has been set to default.")
		endPopup()
	end

	if beginPopup("error: failed to delete config.json") then
		defaultPopupBody("Failed to delete config file: " .. self.popupData.configPath .."\n"..
				"Make sure that you don't have the file open in another program.")
		endPopup()
	end

	if beginPopup("input: delete mod") then
		imgui.Text("Are you sure, you want to delete '" .. self.popupData.name .. "' ?\n"..
				"Mod path: " .. self.popupData.path .. "\n!! THIS CAN'T BE UNDONE !!")

		imgui.Separator()

		if imgui.Button("Yes") then
			bbp.utils.deleteDirectory(self.popupData.path)
			if not love.filesystem.getInfo(self.popupData.path) then
				bbp.utils.setRestartRequired()
				rawset(mods[self.popupData.id], "notSelectable", true)
				openPopup("info: successfully deleted mod", self.popupData)
			else
				openPopup("error: failed to delete mod", self.popupData)
			end
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		endPopup()
	end

	if beginPopup("info: successfully deleted mod") then
		defaultPopupBody("The mod '" .. self.popupData.name .. "' has been deleted.\nPlease restart the game.")
		endPopup()
	end

	if beginPopup("error: failed to delete mod") then
		defaultPopupBody("Failed to delete mod folder: " .. self.popupData.path .."\n"..
				"Make sure that you don't have any files from the folder open in another program.")
		endPopup()
	end

	if beginPopup("input: restart game") then
		imgui.Text("Are you sure, you want to restart the game?")

		imgui.Separator()

		if imgui.Button("Yes") then
			bbp.utils.restart()
		end

		imgui.SameLine()
		if imgui.Button("No") then
			imgui.CloseCurrentPopup()
		end

		endPopup()
	end

	if beginPopup("input: quit with restart required") then
		imgui.Text("You have made some changes that require a restart.\nPlease restart the game.")

		imgui.Separator()

		if imgui.Button("Yes, restart now") then
			bbp.utils.restart()
		end

		imgui.SameLine()
		if imgui.Button("No, return to mod menu") then
			imgui.CloseCurrentPopup()
		end

		endPopup()
	end

	if beginPopup("input: quit with changed mod list") then
		imgui.Text("You have enabled/disabled some of your mods.\nPlease restart the game, or revert these changes.")

		imgui.Separator()

		if imgui.Button("Yes, restart now") then
			bbp.utils.restart()
		end

		imgui.SameLine()
		if imgui.Button("No, return to mod menu") then
			imgui.CloseCurrentPopup()
		end

		endPopup()
	end

	if beginPopup("input: incompatible mods") then
		imgui.TextUnformatted("You have incompatible mods!\n\n" .. self.popupData.problems ..
				"\n\nYou should resolve these issues before continuing.")
		imgui.Separator()

		if imgui.Button("Stay in mod menu") then
			imgui.CloseCurrentPopup()
		end

		imgui.SameLine()
		if imgui.Button("Continue anyway") then
			imgui.CloseCurrentPopup()
			st:loadMainMenu()
		end

		imgui.SameLine()
		if imgui.Button("Close Beatblock") then
			love.event.quit()
		end

		endPopup()
	end

	imgui.End()
	if appliedBBPTheme then
		bbp.gui.popStyle()
	end
end)

return st
