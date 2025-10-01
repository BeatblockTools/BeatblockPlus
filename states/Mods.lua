local st = Gamestate:new('Mods')

local function playClickSound()
    te.play(sounds.hold, 'static', 'sfx', 0.3)
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

local function loadConfigRenderer(mod, path)
    local chunk, errormsg = love.filesystem.load(path)
    if errormsg then
        print("[BB+] Error while loading the config renderer of " .. mod.name .. ". " .. errormsg)
    else
        local env = setmetatable({ mod = mod }, { __index = _G })
        return setfenv(chunk, env)
    end
end

local function renderModConfig(mod)
    imgui.TextWrapped(mod.name .. " (" .. mod.version .. ") by " .. mod.author)
    imgui.TextWrapped(mod.description)
    imgui.Separator()

    -- toggle for the mod
    if mod.id ~= "BeatblockPlus" then
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

    -- if the mod has a config.lua file, use that to render the config gui
    -- else generate it automatically
    local configPath = "Mods/" .. mod.id .. "/config.lua"

    -- if there is a config.lua file but the renderer isn't loaded already, load it
    if not mod.configRenderer and love.filesystem.getInfo(configPath) then
        mod.configRenderer = loadConfigRenderer(mod, configPath)
    end

    if mod.configRenderer then
        mod.configRenderer()
    else
        generateConfig(mod.config)
    end

    if imgui.Button("Save Changes") then
        local modData = {
            id = mod.id,
            name = mod.name,
            author = mod.author,
            description = mod.description,
            version = mod.version,
            enabled = mod.enabled,
            config = mod.config
        }
        dpf.saveJson("Mods/" .. mod.id .. "/mod.json", modData)
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

local function readJsonFromFile(filePath)
    local contents = love.filesystem.read(filePath)
    return json.decode(contents)
end

-- recursively looks for a mod.json and returns the mod data and the parent directory, to later get rid of extra parent folders
local function findModData(currentDirectory)
    local modData
    if love.filesystem.getInfo(currentDirectory .. "/mod.json", 'file') then
        modData = readJsonFromFile(currentDirectory .. "/mod.json")
        modData.directory = currentDirectory
        return modData
    else
        local directoryItems = love.filesystem.getDirectoryItems(currentDirectory)
        for i, filename in ipairs(directoryItems) do
            local fileInfo = love.filesystem.getInfo(currentDirectory .. "/" .. filename)
            if fileInfo and fileInfo.type == "directory" then
                modData = findModData(currentDirectory .. "/" .. filename)
                if modData.id then
                    local topDirectory = string.match(modData.directory, "([^/]+)")
                    if topDirectory ~= "draganddrop" then
                        modData.directory = currentDirectory .. "/" .. modData.directory
                    end
                end
                return modData
            end
        end
    end
end

local function createModFolder(path)
    if love.filesystem.mount(path, "draganddrop") then
        local modpath = "Mods/"
        local modData = findModData("draganddrop")
        -- print("mounted mod files into " .. modData.directory)
        if modData and modData.id then
            modpath = modpath .. modData.id
        else
            print("no modID found")
            return
        end
        if love.filesystem.getInfo(modpath) then
            print("'Mods/" .. modData.id .. "' already exists")
            return
        end
        helpers.recursiveFolderCopy(modpath, modData.directory)
        print("copied mod files to 'Mods/" .. modData.id .. "'")
        love.filesystem.unmount(path)
        -- TODO add interface feedback and tell player to restart game
    end
end

-- dropped folder
function st:directorydropped(path)
    createModFolder(path)
end

-- dropped file
function st:filedropped(file)
    local path = file:getFilename()
    if string.sub(path, -4, -1) ~= ".zip" then
        print(path .. " is not a zip file")
        return
    end
    createModFolder(path)
end

st:setInit(function(self)
    self.selectedModId = "BeatblockPlus"

    self.sortedIDs = {}
    local i = 0
    for modID, _ in pairs(mods) do
        i = i + 1
        self.sortedIDs[i] = modID
    end
    -- the list contains ids, but they're sorted by name
    table.sort(self.sortedIDs, function(a, b)
        return mods[a].name:lower() < mods[b].name:lower()
    end)

    -- ingame cursor doesn't work in the mod menu, so we always use the regular one
    love.mouse.setVisible(true)
end)

st:setUpdate(function(self, dt)
    if maininput:pressed("r") then
        local mod = mods[self.selectedModId]
        if mod.configRenderer then
            local configPath = "Mods/" .. mod.id .. "/config.lua"
            mod.configRenderer = loadConfigRenderer(mod, configPath)
        end

    elseif maininput:pressed("back") then
        self.loadMainMenu(self)
    end
end)

st:setBgDraw(function(self)
    color()
    love.graphics.rectangle('fill', 0, 0, 600, 360)
end)

local windowScale = 2
local windowWidth = 600 * windowScale
local windowHeight = 360 * windowScale

st:setFgDraw(function(self)
    helpers.SetNextWindowPos(0, 0)
    helpers.SetNextWindowSize(windowWidth, windowHeight)
    --												423
    imgui.Begin("Mods", true, 295) -- notitlebar, noresize, nomove, nocollapse, nobackground, nosavedsettings

    imgui.SetWindowFontScale(2)
    imgui.Text("Mods (" .. countTable(mods) .. ")")
    imgui.SetWindowFontScale(1)
    imgui.Separator()

    imgui.BeginChild_Str("mod_list_and_config", imgui.ImVec2_Float(windowWidth, 320 * windowScale), 0)

    imgui.Columns(2, "main", true)
    imgui.SetColumnWidth(imgui.GetColumnIndex(), windowWidth * 0.6)

    -- start drawing mod boxes
    imgui.BeginChild_Str("mod_list", imgui.ImVec2_Float(550 * windowScale, 320 * windowScale), 0)

    for _, modID in pairs(self.sortedIDs) do
        local mod = mods[modID]
        local childWidth = windowWidth * 0.59
        local childHeight = 42 * windowScale -- just enough to fit the mod icon
        imgui.BeginChild_Str("mod_" .. mod.id, imgui.ImVec2_Float(childWidth, childHeight), 1)

        imgui.Columns(2, "mod_details_" .. mod.id, true)

        -- mod icon
        imgui.SetColumnWidth(imgui.GetColumnIndex(), childWidth * 0.227)
        local imageSizeX = 73 * windowScale
        local imageSizeY = 33 * windowScale
        imgui.Image((modIcons[mod.id] or modIcons.unknown), imgui.ImVec2_Float(imageSizeX, imageSizeY))
        imgui.NextColumn()

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
    renderModConfig(mods[self.selectedModId])
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

    imgui.End()
end)

return st
