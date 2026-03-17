local cfg = mod.config

cfg.lightMode = helpers.InputBool("Light Mode", cfg.lightMode)
imgui.SetItemTooltip("Uses the Beatblock Plus theme for the mods menu")

imgui.SeparatorText("auto delete old logs")

imgui.Text("delete files in this directory?")
imgui.SameLine(250)
imgui.Text("how many can stay?")

cfg.delete.crashreports = helpers.InputBool("Beatblock / crashreports", cfg.delete.crashreports)
-- imgui.SameLine()
-- imgui.Text(" |  ")
if cfg.delete.crashreports then
    imgui.SameLine(250)
    imgui.SetNextItemWidth(100)
    cfg.keep.crashreports = helpers.InputInt("", cfg.keep.crashreports)
    cfg.keep.crashreports = math.max(0, cfg.keep.crashreports)
else
    cfg.delete.crashreports = false
end

cfg.delete.logs = helpers.InputBool("Beatblock / logs", cfg.delete.logs)
-- imgui.SameLine()
-- imgui.Text("             |  ")
if cfg.delete.logs then
    imgui.SameLine(250)
    imgui.SetNextItemWidth(100)
    cfg.keep.logs = helpers.InputInt(" ", cfg.keep.logs)
    cfg.keep.logs = math.max(0, cfg.keep.logs)
else
    cfg.delete.logs = false
end

cfg.delete.lovelylogs = helpers.InputBool("Mods / lovely / log", cfg.delete.lovelylogs)
-- imgui.SameLine()
-- imgui.Text("          |  ")
if cfg.delete.lovelylogs then
    imgui.SameLine(250)
    imgui.SetNextItemWidth(100)
    cfg.keep.lovelylogs = helpers.InputInt("  ", cfg.keep.lovelylogs)
    cfg.keep.lovelylogs = math.max(0, cfg.keep.lovelylogs)
else
    cfg.delete.lovelylogs = false
end
