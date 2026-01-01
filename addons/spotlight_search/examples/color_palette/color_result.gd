@tool
extends SpotlightResultItem
class_name ColorPaletteResult

const ColorWidgetScript = preload("res://addons/spotlight_search/examples/color_palette/color_palette_widget.gd")

func _init():
	title = "Color Palette"
	description = "Pick a color and copy Hex/Vec4"
	icon = EditorInterface.get_editor_theme().get_icon("ColorPicker", "EditorIcons")
	type = ItemType.LEAF
	tags = ["WenQian", "Tool"]

# --- 预览类型：自定义 ---
func get_preview_type() -> PreviewType:
	return PreviewType.CUSTOM

# --- 创建自定义预览控件 ---
func create_custom_preview() -> Control:
	return ColorWidgetScript.new()

func get_unique_id() -> String:
	return "example.color_palette"

func execute():
	# 执行时不做特别操作，主要是为了打开预览面板
	pass
