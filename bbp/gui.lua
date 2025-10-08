local gui = {}

-- Quick way to create a checkbox.
-- Returns 2 values, new value and whether it was changed
--
-- Examples:
-- local changed
-- mod.enabled, changed = bbp.imgui.checkbox("Mod Enabled", mod.enabled)
-- if changed then
--   print("Mod was " .. (mod.enabled and "enabled" or "disabled"))
-- end 
function gui.checkbox(label, value)
    local ptr = ffi.new("bool[1]", value)
    if imgui.Checkbox(label, ptr) then
        return ptr[0], true
    end
    return value, false
end

return gui