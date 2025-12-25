@tool
extends VBoxContainer

# 一个简单的计算器 UI 实现
# 用于展示 Spotlight 的 Custom Preview 功能

var display: Label
var current_input: String = ""
var previous_input: float = 0.0
var operation: String = ""
var should_reset: bool = false

func _init():
	# 1. 设置布局
	add_theme_constant_override("separation", 10)
	
	# 2. 显示屏
	var bg = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)
	
	display = Label.new()
	display.text = "0"
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	display.add_theme_font_size_override("font_size", 32)
	bg.add_child(display)
	
	# 3. 按钮网格
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(grid)
	
	var buttons = [
		"7", "8", "9", "/",
		"4", "5", "6", "*",
		"1", "2", "3", "-",
		"C", "0", "=", "+"
	]
	
	for btn_text in buttons:
		var btn = Button.new()
		btn.text = btn_text
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.size_flags_vertical = SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(func(): _on_button_pressed(btn_text))
		grid.add_child(btn)

func _on_button_pressed(text: String):
	if text.is_valid_float():
		if display.text == "0" or should_reset:
			display.text = text
			should_reset = false
		else:
			display.text += text
	elif text == "C":
		display.text = "0"
		current_input = ""
		previous_input = 0.0
		operation = ""
	elif text == "=":
		if operation != "":
			var result = _calculate(previous_input, float(display.text), operation)
			display.text = str(result)
			operation = ""
			should_reset = true
	else:
		# Operators
		previous_input = float(display.text)
		operation = text
		should_reset = true

func _calculate(a: float, b: float, op: String) -> float:
	match op:
		"+": return a + b
		"-": return a - b
		"*": return a * b
		"/": return 0.0 if b == 0 else a / b
	return 0.0
