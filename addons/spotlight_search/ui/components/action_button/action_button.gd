extends Button

var action: SpotlightAction

func _ready():
	_update_theme()

func setup(p_action: SpotlightAction):
	action = p_action
	var label = $HBoxContainer/Text
	if label:
		label.text = p_action.text
	
	var shortcut_label = $HBoxContainer/ShortcutLabel
	if shortcut_label:
		shortcut_label.text = p_action.shortcut_text
	
	pressed.connect(p_action.callback)

func _update_theme():
	var label = $HBoxContainer/Text
	if label:
		label.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	
	var shortcut_label = $HBoxContainer/ShortcutLabel
	if shortcut_label:
		shortcut_label.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))

	# 简单的样式调整，使其融入编辑器
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = get_theme_color("dark_color_3", "Editor")
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.corner_radius_bottom_left = 4
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = get_theme_color("dark_color_2", "Editor")
	
	add_theme_stylebox_override("normal", style_normal)
	add_theme_stylebox_override("hover", style_hover)
