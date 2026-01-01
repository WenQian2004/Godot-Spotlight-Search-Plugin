@tool
extends SpotlightSimpleExtension

const ColorWidgetScript = preload("res://addons/spotlight_search/examples/color_palette/color_palette_widget.gd")

func _init():
	# 注册 -color 命令
	add_command("-color", "Color Palette") \
		.set_description("Pick and manage colors.") \
		.set_icon("ColorPicker") \
		.set_preview_custom(ColorWidgetScript) \
		.set_tags(["WenQian", "Tool"])

func get_id() -> String:
	return "example.color_palette"

func get_display_name() -> String:
	return "Color Palette"

func get_author() -> String:
	return "WenQian"
