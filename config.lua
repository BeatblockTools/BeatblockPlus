local cfg = mod.config

cfg.lightMode = helpers.InputBool("Light Mode", cfg.lightMode)
imgui.SetItemTooltip("Uses the Beatblock Plus theme for the mods menu")

imgui.SeparatorText("auto delete old logs")

imgui.Text("delete files in this directory?")
imgui.SameLine(250)
imgui.Text("how many can stay?")

cfg.delete.crashreports = helpers.InputBool("Beatblock / crashreports", cfg.delete.crashreports)
if cfg.delete.crashreports then
    imgui.SameLine(250)
    imgui.SetNextItemWidth(100)
    cfg.keep.crashreports = helpers.InputInt("", cfg.keep.crashreports)
    cfg.keep.crashreports = math.max(1, cfg.keep.crashreports)
else
    cfg.delete.crashreports = false
end

cfg.delete.logs = helpers.InputBool("Beatblock / logs", cfg.delete.logs)
if cfg.delete.logs then
    imgui.SameLine(250)
    imgui.SetNextItemWidth(100)
    cfg.keep.logs = helpers.InputInt(" ", cfg.keep.logs)
    cfg.keep.logs = math.max(1, cfg.keep.logs)
else
    cfg.delete.logs = false
end

cfg.delete.lovelylog = helpers.InputBool("Mods / lovely / log", cfg.delete.lovelylog)
if cfg.delete.lovelylog then
    imgui.SameLine(250)
    imgui.SetNextItemWidth(100)
    cfg.keep.lovelylog = helpers.InputInt("  ", cfg.keep.lovelylog)
    cfg.keep.lovelylog = math.max(1, cfg.keep.lovelylog)
else
    cfg.delete.lovelylog = false
end
