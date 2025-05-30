local st = Gamestate:new('Mods')
local selectedModPage = 1
local modsPerPage = 8
local configToRender = nil
local modIndices = {}

local buttons = {}

local function playClickSound()
	te.play(sounds.hold, 'static', 'sfx', 0.3)
end

local function addButton(x, y, width, height, callback)
	local button = {
		x1 = x,
		y1 = y,
		x2 = x + width,
		y2 = y + height,
		callback = function()
			playClickSound()
			callback()
		end
	}
	table.insert(buttons, button)
end

local function isMouseOverButton(button)
	return mouse.rx >= button.x1 and mouse.rx <= button.x2 and mouse.ry >= button.y1 and mouse.ry <= button.y2
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

local function renderModConfig(mod)
	imgui.Begin(mod.name .. " Config")
	imgui.TextWrapped(mod.name .. " (" .. mod.version .. ") by " .. mod.author)
	imgui.TextWrapped(mod.description)
	imgui.Separator()

	if mod.id ~= "beatblock-plus" then
		local enabledPtr = ffi.new("bool[1]", mod.enabled)
		if imgui.Checkbox("Enabled (Requires Restart)", enabledPtr) then
			mod.enabled = enabledPtr[0]

			local modPath = "Mods/" .. mod.id .. "/lovely/"
			local disabledPath = "Mods/disabled/" .. mod.id .. "/lovely/"

			if mod.enabled then
				moveDirectory(disabledPath, modPath)
			else
				moveDirectory(modPath, disabledPath)
			end
		end
	end

	local function renderConfig(config)
		for k, v in pairs(config) do
			if type(v) == "table" then
				imgui.Separator()
				imgui.TextWrapped(k)
				renderConfig(v)
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

	-- if the mod has a config.lua file, use that to render the config gui
	-- else generate it automatically
	local configPath = "Mods/" .. mod.id .. "/config.lua"
	if love.filesystem.getInfo(configPath) then
		local chunk, errormsg = love.filesystem.load(configPath)
		if errormsg then
			print("[BB+] Error while loading the config renderer of " .. mod.name .. ". " .. errormsg)
		else
			local env = setmetatable({ mod = mod }, { __index = _G })
			setfenv(chunk, env)()
		end
	else
		renderConfig(mod.config)
	end

	if imgui.Button("Save and Close") then
		dpf.saveJson("Mods/" .. mod.id .. "/mod.json", mod)
		configToRender = nil
	end

	imgui.End()
end

local function truncateText(inputText, maxWidth)
	local beforeNewline = inputText:match("^(.-)\n")
	if beforeNewline then
		inputText = beforeNewline
	end
	if love.graphics.getFont():getWidth(inputText) <= maxWidth then
		return inputText
	end
	local ellipsis = "..."
	for i = #inputText, 1, -1 do
		local shortenedText = inputText:sub(1, i) .. ellipsis
		if love.graphics.getFont():getWidth(shortenedText) <= maxWidth then
			return shortenedText
		end
	end
	return inputText:len() <= maxWidth and inputText or ellipsis
end

local function printCenteredText(string, y)
	love.graphics.setFont(fonts.digitalDisco)
	color(1) -- black
	love.graphics.printf(string, 0, y, 600, 'center')
	-- text, x, y, limit, align
end

local function drawModPage(page)
	-- print title
	printCenteredText("Mods (" .. #modIndices .. ")", 1)
	love.graphics.line(0, 18, 600, 18)

	-- print mods
	local startIndex = (page - 1) * modsPerPage + 1
	local endIndex = math.min(startIndex + modsPerPage - 1, #modIndices)

	local modListTopPadding = 26
	local paddingBetweenEachMod = 5
	local boxWidth = 550
	local boxHeight = 34

	color(1) -- black

	local y = modListTopPadding

	buttons = {}

	for i = startIndex, endIndex do
		local mod = mods[modIndices[i]]

		-- if the mod is disabled, put a red tint in the background
		if not mod.enabled then
			love.graphics.setColor(1, 0, 0, 0.1)
			love.graphics.rectangle('fill', 25, y, boxWidth, boxHeight)
		end

		-- draw a hollow box around the mod info
		color(1) -- black
		love.graphics.rectangle('line', 25, y, boxWidth, boxHeight)

		-- draw config button
		love.graphics.rectangle('line', 559, y, 16, 16)
		addButton(559, y, 16, 16, function()
			local window_width, window_height = 500, 500
			local window_flags = 16 -- NoSavedSettings
			helpers.SetNextWindowPos(15, 15, window_flags)
			helpers.SetNextWindowSize(window_width, window_height, window_flags)
			configToRender = mod
		end)
		color(0) -- white
		love.graphics.draw(sprites.bbp.settings, 560, y + 1)

		-- draw the icon
		love.graphics.draw(modIcons[mod.id] or modIcons.unknown, 25, y)
		color(1) -- black

		local textWidth = 500
		local textX = 100
		local modInfo = mod.name .. " by " .. mod.author .. " (v" .. mod.version .. ")"
		if not mod.enabled then
			modInfo = modInfo .. " [Disabled]"
		end
		love.graphics.printf(truncateText(modInfo, textWidth), textX, y, textWidth, "left")
		love.graphics.printf(truncateText(mod.description, textWidth - 50), textX, y + 17, textWidth, "left")

		y = y + boxHeight + paddingBetweenEachMod
	end

	-- print footer
	printCenteredText("Page " .. page, 343)

	-- decide whether to show the next page button
	local arrowWidth = love.graphics.getFont():getWidth("[>]")
	local arrowHeight = love.graphics.getFont():getHeight()

	if modsPerPage * page < #modIndices then
		love.graphics.print("[>]", 357, 343)
		addButton(357, 343, arrowWidth, arrowHeight, function()
			selectedModPage = selectedModPage + 1
		end)
	end

	-- decide whether to show the previous page button
	if page > 1 then
		love.graphics.print("[<]", 228, 343)
		addButton(228, 343, arrowWidth, arrowHeight, function()

			selectedModPage = selectedModPage - 1
		end)
	end

	-- draw horizontal line above footer
	love.graphics.line(0, 342, 600, 342)
end

st:setInit(function(self)
	shuv.usePalette = false

	local i = 0
	modIndices = {}

	for modId, _ in pairs(mods) do
		i = i + 1
		modIndices[i] = modId
	end

	table.sort(modIndices, function(a, b)
		return a:lower() < b:lower()
	end)
end)

st:setUpdate(
	function(self, dt)
		if maininput:pressed("mouse1") then
			for _, btn in ipairs(buttons) do
				if isMouseOverButton(btn) then
					btn.callback()
				end
			end
		end
		if maininput:pressed('menu_right') then
			playClickSound()
			if modsPerPage * selectedModPage < #modIndices then
				selectedModPage = selectedModPage + 1
				drawModPage(selectedModPage)
			end
		elseif maininput:pressed('menu_left') then
			playClickSound()
			if selectedModPage > 1 then
				selectedModPage = selectedModPage - 1
				drawModPage(selectedModPage)
			end
		elseif maininput:pressed('back') then
			playClickSound()
			cs = bs.load('Menu')
			self.menuMusicManager:clearOnBeatHooks()
			cs.menuMusicManager = self.menuMusicManager
			cs:init()
			shuv.usePalette = true
		end
	end
)

st:setBgDraw(function(self)
	love.graphics.setFont(fonts.digitalDisco)
	color()
	love.graphics.rectangle('fill', 0, 0, 600, 360)
end)

st:setFgDraw(function(self)
	drawModPage(selectedModPage)
	if configToRender ~= nil then
		renderModConfig(configToRender)
	end
end)

return st
