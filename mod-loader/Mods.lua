local st = Gamestate:new('Mods')
local selectedModPage = 1
local modsPerPage = 8

local function truncateText(inputText, maxWidth)
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
	printCenteredText("Mods (" .. #mods .. ")", 1)
	love.graphics.line(0, 18, 600, 18)

	-- print mods
	local startIndex = (page - 1) * modsPerPage + 1
	local endIndex = math.min(startIndex + modsPerPage - 1, #mods)

	local modListTopPadding = 26
	local paddingBetweenEachMod = 5
	local boxWidth = 550
	local boxHeight = 34

	color(1) -- black

	local y = modListTopPadding

	for i = startIndex, endIndex do
		local mod = mods[i]

		-- draw a hollow box around the mod info
		love.graphics.rectangle("line", 25, y, boxWidth, boxHeight)

		-- draw the icon
		color(0) -- white
		love.graphics.draw(modIcons[mod.id] or modIcons.unknown, 25, y)
		color(1) -- black

		local textWidth = 525
		local textX = 100
		local modInfo = mod.name .. " by " .. mod.author .. " (v" .. mod.version .. ")"
		love.graphics.printf(truncateText(modInfo, textWidth), textX, y, textWidth, "left")
		love.graphics.printf(truncateText(mod.description, textWidth - 50), textX, y + 17, textWidth, "left")

		y = y + boxHeight + paddingBetweenEachMod
	end

	-- print footer
	local footer = "     Page " .. page .. "     "

	-- decide whether it should show the next page button
	if modsPerPage * page < #mods then
		footer = footer .. "[>]"
	end
	-- decide whether it should show the previous page button
	if page > 1 then
		footer = "[<]" .. footer
	end

	printCenteredText(footer, 343)
	love.graphics.line(0, 342, 600, 342)
end

st:setInit(function(self)
	shuv.usePalette = false
end)

st:setUpdate(
	function(self, dt)
		if maininput:pressed('menu_right') then
			if modsPerPage * selectedModPage < #mods then
				selectedModPage = selectedModPage + 1
				drawModPage(selectedModPage)
			end
		elseif maininput:pressed('menu_left') then
			if selectedModPage > 1 then
				selectedModPage = selectedModPage - 1
				drawModPage(selectedModPage)
			end
		else
			if maininput:pressed('back') then
				cs = bs.load('Menu')
				self.menuMusicManager:clearOnBeatHooks()
				cs.menuMusicManager = self.menuMusicManager
				cs:init()
				shuv.usePalette = true
			end
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
end)

return st
