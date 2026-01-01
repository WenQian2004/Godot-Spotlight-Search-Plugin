@tool

extends ScrollContainer

var color_picker: ColorPicker
var hex_btn: Button
var vec_btn: Button

func _ready():
	# 允许水平和垂直扩展
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 创建内部容器
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	# 1. 顶部操作栏
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	hex_btn = Button.new()
	hex_btn.text = "Copy Hex"
	hex_btn.icon = get_theme_icon("ActionCopy", "EditorIcons")
	hex_btn.pressed.connect(_on_copy_hex)
	hbox.add_child(hex_btn)
	
	vec_btn = Button.new()
	vec_btn.text = "Copy Vec4"
	vec_btn.icon = get_theme_icon("Vector4", "EditorIcons")
	vec_btn.pressed.connect(_on_copy_vec)
	hbox.add_child(vec_btn)
	
	# 2. 颜色选择器
	color_picker = ColorPicker.new()
	# 简化界面，隐藏不常用的部分
	color_picker.edit_alpha = true
	color_picker.deferred_mode = true
	color_picker.can_add_swatches = true
	color_picker.presets_visible = true
	# 让 ColorPicker 在垂直方向上扩展，但不要强制填充，以免在ScrollContainer中被拉得太长
	color_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 尝试设置一些默认模式
	color_picker.picker_shape = ColorPicker.SHAPE_HSV_RECTANGLE
	
	vbox.add_child(color_picker)

func _on_copy_hex():
	var col = color_picker.color
	var hex = col.to_html(true) # include alpha
	DisplayServer.clipboard_set(hex)
	_show_toast("Copied: #" + hex)

func _on_copy_vec():
	var col = color_picker.color
	var text = "Color(%.3f, %.3f, %.3f, %.3f)" % [col.r, col.g, col.b, col.a]
	DisplayServer.clipboard_set(text)
	_show_toast("Copied: " + text)

func _show_toast(text: String):
	var original_text = hex_btn.text
	hex_btn.text = "Copied!"
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(hex_btn):
		hex_btn.text = original_text
