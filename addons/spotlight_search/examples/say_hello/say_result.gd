@tool
extends SpotlightResultItem
class_name SayResult

## 自定义 Result 类型，用于演示自定义预览面板
## 右侧面板包含输入框和按钮

var command_id: String
var command_callback: Callable

func _init(p_id: String = "", p_title: String = "", p_desc: String = "", p_icon: Texture2D = null):
	command_id = p_id
	title = p_title
	description = p_desc
	icon = p_icon
	type = ItemType.LEAF  # 叶子节点，但有自定义预览

# --- 预览类型：自定义 ---
func get_preview_type() -> PreviewType:
	return PreviewType.CUSTOM

# --- 创建自定义预览控件 ---
func create_custom_preview() -> Control:
	var base_path = get_script().resource_path.get_base_dir()
	var scene_path = base_path + "/hello_preview.tscn"
	
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		var instance = scene.instantiate()
		if instance.has_method("setup"):
			instance.setup(self)
		return instance
	else:
		var lbl = Label.new()
		lbl.text = "Error: hello_preview.tscn not found!"
		return lbl

# --- 辅助方法：创建标签芯片 ---
func _create_tag_chip(tag: String) -> PanelContainer:
	var chip = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = EditorInterface.get_editor_theme().get_color("dark_color_3", "Editor")
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	
	# 特殊颜色: WenQian
	if tag == "WenQian":
		style.bg_color = Color(0.9, 0.5, 0.2, 0.2)  # 橙色系
	elif tag == "Community":
		style.bg_color = Color(0.5, 0.8, 0.3, 0.2)  # 绿色系
	elif tag == "Interactive":
		style.bg_color = Color(0.3, 0.6, 0.9, 0.2)  # 蓝色系
	
	chip.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = tag
	label.add_theme_font_size_override("font_size", 10)
	
	if tag == "WenQian":
		label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	elif tag == "Community":
		label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.3))
	elif tag == "Interactive":
		label.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
	else:
		label.add_theme_color_override("font_color", EditorInterface.get_editor_theme().get_color("font_color", "Editor").darkened(0.2))
	
	chip.add_child(label)
	return chip

# --- 执行方法 (可选，用于双击/Enter 时的行为) ---
func execute():
	# 由于这是一个交互式命令，execute 可以不做任何事
	# 或者可以聚焦到输入框
	print("[WenQian Say] Please use the input panel on the right.")

func get_unique_id() -> String:
	return command_id

func get_preview_content() -> Dictionary:
	return { "text": description }
