local gui = {}

local _imguiFonts = {}

-- Registers a new ImGui font
function gui.registerFont(id, fontPath, fontSize)
	local imio = imgui.GetIO()
	local config = imgui.ImFontConfig()
	config.FontDataOwnedByAtlas = false
	config.Name = id

	local content, size = love.filesystem.read(fontPath)
	_imguiFonts[id] = imio.Fonts:AddFontFromMemoryTTF(ffi.cast('void*', content), size, fontSize, config)

	imgui.love.BuildFontAtlas()
	return _imguiFonts[id]
end

function gui.getFont(id)
	return _imguiFonts[id]
end

-- Pushes the BeatblockPlus ImGui theme.
-- Make sure to call bbp.gui.popStyle() after you are done!
function gui.pushStyle()
	local font = gui.getFont('disco') or bbp.gui.registerFont('disco', 'assets/fonts/DigitalDisco-Thin.ttf', 16)
	imgui.PushFont(font)

	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_FrameBorderSize,    1.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_Alpha,              1.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_DisabledAlpha,      0.5)
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_WindowPadding,       imgui.ImVec2_Float(10.0, 8.0))
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_WindowRounding,     0.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_WindowBorderSize,   1.0)
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_WindowMinSize,       imgui.ImVec2_Float(32.0, 32.0))
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_WindowTitleAlign,    imgui.ImVec2_Float(0.5, 0.5))
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_ChildRounding,      0.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_ChildBorderSize,    1.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_PopupRounding,      0.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_PopupBorderSize,    1.0)
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_FramePadding,        imgui.ImVec2_Float(4.0, 3.0))
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_FrameRounding,      0.0)
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_ItemSpacing,         imgui.ImVec2_Float(8.0, 4.0))
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_ItemInnerSpacing,    imgui.ImVec2_Float(4.0, 4.0))
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_CellPadding,         imgui.ImVec2_Float(4.0, 2.0))
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_IndentSpacing,      21.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_ScrollbarSize,      14.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_ScrollbarRounding,  9.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_GrabMinSize,        10.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_GrabRounding,       0.0)
	imgui.PushStyleVar_Float(imgui.ImGuiStyleVar_TabRounding,        4.0)
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_ButtonTextAlign,     imgui.ImVec2_Float(0.5, 0.5))
	imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_SelectableTextAlign, imgui.ImVec2_Float(0.0, 0.0))

	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Text,                      imgui.ImVec4_Float(0.00, 0.00, 0.00, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TextDisabled,              imgui.ImVec4_Float(0.60, 0.60, 0.60, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_WindowBg,                  imgui.ImVec4_Float(0.94, 0.94, 0.94, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ChildBg,                   imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_PopupBg,                   imgui.ImVec4_Float(1.00, 1.00, 1.00, 0.98))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Border,                    imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.30))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_BorderShadow,              imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_FrameBg,                   imgui.ImVec4_Float(1.00, 1.00, 1.00, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_FrameBgHovered,            imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_FrameBgActive,             imgui.ImVec4_Float(0.65, 0.65, 0.65, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TitleBg,                   imgui.ImVec4_Float(0.96, 0.96, 0.96, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TitleBgActive,             imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TitleBgCollapsed,          imgui.ImVec4_Float(1.00, 1.00, 1.00, 0.51))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_MenuBarBg,                 imgui.ImVec4_Float(0.86, 0.86, 0.86, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ScrollbarBg,               imgui.ImVec4_Float(0.98, 0.98, 0.98, 0.53))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ScrollbarGrab,             imgui.ImVec4_Float(0.69, 0.69, 0.69, 0.80))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ScrollbarGrabHovered,      imgui.ImVec4_Float(0.49, 0.49, 0.49, 0.80))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ScrollbarGrabActive,       imgui.ImVec4_Float(0.49, 0.49, 0.49, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_CheckMark,                 imgui.ImVec4_Float(0.00, 0.00, 0.00, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_SliderGrab,                imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.34))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_SliderGrabActive,          imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.61))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Button,                    imgui.ImVec4_Float(1.00, 1.00, 1.00, 0.40))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ButtonHovered,             imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ButtonActive,              imgui.ImVec4_Float(0.66, 0.66, 0.66, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Header,                    imgui.ImVec4_Float(1.00, 1.00, 1.00, 0.31))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_HeaderHovered,             imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_HeaderActive,              imgui.ImVec4_Float(0.65, 0.65, 0.65, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Separator,                 imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.62))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_SeparatorHovered,          imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.78))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_SeparatorActive,           imgui.ImVec4_Float(0.00, 0.00, 0.00, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ResizeGrip,                imgui.ImVec4_Float(0.35, 0.35, 0.35, 0.17))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ResizeGripHovered,         imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ResizeGripActive,          imgui.ImVec4_Float(0.65, 0.65, 0.65, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TabHovered,                imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Tab,                       imgui.ImVec4_Float(1.00, 1.00, 1.00, 0.93))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TabSelected,               imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TabSelectedOverline,       imgui.ImVec4_Float(0.30, 0.30, 0.30, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TabDimmed,                 imgui.ImVec4_Float(0.07, 0.10, 0.15, 0.97))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TabDimmedSelected,         imgui.ImVec4_Float(0.14, 0.26, 0.42, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TabDimmedSelectedOverline, imgui.ImVec4_Float(0.50, 0.50, 0.50, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_DockingPreview,            imgui.ImVec4_Float(0.26, 0.59, 0.98, 0.70))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_DockingEmptyBg,            imgui.ImVec4_Float(0.20, 0.20, 0.20, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_PlotLines,                 imgui.ImVec4_Float(0.39, 0.39, 0.39, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_PlotLinesHovered,          imgui.ImVec4_Float(1.00, 0.43, 0.35, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_PlotHistogram,             imgui.ImVec4_Float(0.90, 0.70, 0.00, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_PlotHistogramHovered,      imgui.ImVec4_Float(1.00, 0.45, 0.00, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TableHeaderBg,             imgui.ImVec4_Float(0.78, 0.87, 0.98, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TableBorderStrong,         imgui.ImVec4_Float(0.57, 0.57, 0.64, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TableBorderLight,          imgui.ImVec4_Float(0.68, 0.68, 0.74, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TableRowBg,                imgui.ImVec4_Float(0.00, 0.00, 0.00, 0.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TableRowBgAlt,             imgui.ImVec4_Float(0.30, 0.30, 0.30, 0.09))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TextLink,                  imgui.ImVec4_Float(0.26, 0.59, 0.98, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_TextSelectedBg,            imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_DragDropTarget,            imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_NavHighlight,              imgui.ImVec4_Float(0.82, 0.82, 0.82, 1.00))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_NavWindowingHighlight,     imgui.ImVec4_Float(0.70, 0.70, 0.70, 0.70))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_NavWindowingDimBg,         imgui.ImVec4_Float(0.20, 0.20, 0.20, 0.20))
	imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ModalWindowDimBg,          imgui.ImVec4_Float(0.20, 0.20, 0.20, 0.35))
end

-- Pops the ImGui style
function gui.popStyle()
	imgui.PopStyleColor(58)
	imgui.PopStyleVar(25)
	imgui.PopFont()
end

return gui
