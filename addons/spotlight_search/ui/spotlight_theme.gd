@tool
extends RefCounted

# Colors - Palette: "Catppuccin Mocha" inspired
const COL_BG = Color("#1e1e2e")
const COL_SURFACE = Color("#313244")
const COL_SURFACE_LIGHT = Color("#45475a")
const COL_ACCENT = Color("#89b4fa") # Blue
const COL_ACCENT_HOVER = Color("#b4fa89") # Green-ish
const COL_TEXT_MAIN = Color("#cdd6f4")
const COL_TEXT_DIM = Color("#a6adc8")
const COL_BORDER = Color("#585b70")
const COL_HIGHLIGHT = Color("#313244") # Selection bg
const COL_SELECTION = Color("#45475a")
const COL_SUCCESS = Color("#a6e3a1")
const COL_WARNING = Color("#f9e2af")
const COL_ERROR = Color("#f38ba8")

# Metrics
const CORNER_RADIUS = 8
const PADDING_OUTER = 12
const PADDING_ITEM = 8
const FONT_SIZE_LARGE = 20
const FONT_SIZE_NORMAL = 16
const FONT_SIZE_SMALL = 14
const ITEM_HEIGHT = 44

static func get_main_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COL_BORDER
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = PADDING_OUTER
	style.content_margin_right = PADDING_OUTER
	style.content_margin_top = PADDING_OUTER
	style.content_margin_bottom = PADDING_OUTER
	return style

static func get_search_bar_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COL_SURFACE
	style.corner_radius_top_left = CORNER_RADIUS / 2
	style.corner_radius_top_right = CORNER_RADIUS / 2
	style.corner_radius_bottom_left = CORNER_RADIUS / 2
	style.corner_radius_bottom_right = CORNER_RADIUS / 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func get_item_stylebox(selected: bool = false, hover: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	if selected:
		style.bg_color = COL_SELECTION
		style.border_width_left = 2
		style.border_color = COL_ACCENT
	elif hover:
		style.bg_color = COL_SURFACE_LIGHT
		style.border_width_left = 0
	else:
		style.bg_color = Color(0, 0, 0, 0) # Transparent
		style.border_width_left = 0
		
	return style

static func apply_fonts(node: Control):
	pass
