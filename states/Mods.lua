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

	imgui.SameLine()

	if imgui.Button("Delete Mod") then
		openPopup("delete mod confirmation", {name = mod.name, path = mod.path, id = mod.id})
	end	
	
	if imgui.Button("Save Changes") then
		self.savedConfigDisplayTimer = love.timer.getTime()
		dpf.saveJson(mod.path .. "/config.json", mod.config)
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

-- I don't know if there is a way without this
local function countTable(tbl)
	local count = 0

	for _, _ in pairs(tbl) do
		count = count + 1
	end

	return count
end

st.loadMainMenu = function(self)
	cs = bs.load('Menu')
	self.menuMusicManager:clearOnBeatHooks()
	cs.menuMusicManager = self.menuMusicManager
	cs:init()

	-- return to ingame cursor if the settings say so
	if savedata.options.game.customCursorInMenu and (savedata.options.game.cursorMode ~= "default") then
		love.mouse.setVisible(false)
	end
end

-- look for directory/folder-name/mod.json and return folder-name
local function findModFolder(directory)
	local modFolder
	local directoryItems = love.filesystem.getDirectoryItems(directory)
	for _, item in pairs(directoryItems) do
		local fileInfo = love.filesystem.getInfo(directory .. "/" .. item)
		if fileInfo and fileInfo.type == "directory" then
			if love.filesystem.getInfo(directory .. "/" .. item .. "/" .. "mod.json") then
				modFolder = item
				break
			end
		end
	end
	return modFolder
end

function st:directorydropped(path)
	openPopup("error: folder dropped")
end

function st:filedropped(file)
	local path = file:getFilename()
	if string.sub(path, -4, -1) ~= ".zip" then
		print("not a valid zip file: " .. path)
		openPopup("error: invalid file type dropped")
		return
	end

	if love.filesystem.mount(path, "draganddrop") then
		local modsPath = "Mods/"
		local modFolder = findModFolder("draganddrop")
		
		if not modFolder then
			print("couldn't find mod.json in zip file: " .. path)
			openPopup("error: no mod.json found")
			love.filesystem.unmount(path)
			return
		end

		local fullPath = modsPath..modFolder

		if love.filesystem.getInfo(fullPath) then
			openPopup("error: mod already exists", {modFolder = modFolder})
			love.filesystem.unmount(path)
			return
		end

		love.filesystem.createDirectory(fullPath)
		helpers.recursiveFolderCopy(fullPath, "draganddrop".."/"..modFolder)
		local modData = dpf.loadJson(fullPath.."/".."mod.json")
		openPopup("new mod added", modData)
		love.filesystem.unmount(path)
	else
		-- I think this only happens if someone drags a completely empty zip into the game.
		print("didn't mount draganddrop directory")
		return
	end
end

st:setInit(function(self)
	love.keyboard.setTextInput(true)

	self.selectedModId = "beatblock-plus"

	self.sortedIDs = {}
	local i = 0
	for modID, _ in pairs(bbp.mods) do
		i = i + 1
		self.sortedIDs[i] = modID
	end
	-- the list contains ids, but they're sorted by name
	table.sort(self.sortedIDs, function(a, b)
		return bbp.mods[a].name:lower() < bbp.mods[b].name:lower()
	end)

	-- ingame cursor doesn't work in the mod menu, so we always use the regular one
	love.mouse.setVisible(true)
end)

st:setUpdate(function(self, dt)
	if maininput:pressed("r") then
		-- clear config renderer cache
		rawset(bbp.mods[self.selectedModId], '_configRenderer', nil)
	elseif maininput:pressed("back") then
		self.loadMainMenu(self)
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
	if mod.config.modMenuGuiTheme then
		bbp.gui.pushStyle()
		appliedBBPTheme = true
	end
	imgui.Begin("Mods", true, 295) -- notitlebar, noresize, nomove, nocollapse, nobackground, nosavedsettings

	imgui.SetWindowFontScale(2)
	imgui.Text("Mods (" .. countTable(bbp.mods) .. ")")
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
		imgui.TextWrapped(mod.description)

		-- show config when clicked
		if imgui.IsWindowHovered() and imgui.IsMouseClicked(0) then -- left click
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
		self.loadMainMenu(self)
	end

	imgui.SameLine()

	if imgui.Button("Open Folder") then
		love.system.openURL("file://" .. love.filesystem.getSaveDirectory() .. '/Mods')
	end

	--popups

	local popupFlags = bit.bor(imgui.ImGuiWindowFlags_AlwaysAutoResize, imgui.ImGuiWindowFlags_NoResize, imgui.ImGuiWindowFlags_NoMove, imgui.ImGuiCond_Always)

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

	if imgui.BeginPopupModal("error: folder dropped", nil, popupFlags) then
		popupBody("Drag and drop is not supported for folders. Please use a zip file.\nNo mod was added.")
		imgui.EndPopup()
	end

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

		imgui.Text("Are you sure, you want to reset the config of '" .. self.popupData.name .. "'?\n!! THIS CAN'T BE UNDONE !!")

		imgui.Separator()
		if imgui.Button("Yes") then
			self.popupData.configPath = self.popupData.path .. "/config.json"

			if not love.filesystem.getInfo(self.popupData.configPath) then
				openPopupNextFrame(self, "error: no config.json found", self.popupData)
			end

			dpf.saveJson(self.popupData.configPath, mod.config)
			
			local success = love.filesystem.remove(self.popupData.configPath)
			if success then
				for k, v in pairs(bbp.mods[self.popupData.id].defaultConfig) do
					bbp.mods[self.popupData.id].config[k] = v
				end
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
		popupBody("Are you sure, you want to delete '" .. self.popupData.name .. "'?\n!! THIS CAN'T BE UNDONE !!")
		imgui.EndPopup()
	end

	imgui.End()
	if appliedBBPTheme then
		bbp.gui.popStyle()
	end
end)

return st
