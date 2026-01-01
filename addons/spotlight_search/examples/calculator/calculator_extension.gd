@tool
extends SpotlightSimpleExtension

# 这是一个使用 Spotlight Search 的扩展开发教程示例
# 实现了：
# 1. 自定义指令 (-calc)
# 2. 多级嵌套 (Category)
# 3. 自定义侧边栏 UI (Custom Preview)

const CalculatorWidgetScript = preload("res://addons/spotlight_search/examples/calculator/calculator_widget.gd")

func _init():
	# 1. 顶层命令 -calc
	var calc = add_command("-calc", "Calculator Tools") \
		.set_description("Access calculator utilities.") \
		.set_icon("Edit")
		
	# 2. 标准计算器
	# 这里我们使用 set_preview_factory 来创建 CalculatorWidget
	# CalculatorWidget 需要一个 mode 参数
	calc.add_command("std", "Standard Calculator") \
		.set_description("A simple standard calculator.") \
		.set_title("Standard Calculator") \
		.set_preview_factory(func(): return CalculatorWidgetScript.new("standard"))
		
	# 3. 科学计算器
	calc.add_command("sci", "Scientific Calculator") \
		.set_description("Advanced calculator with scientific functions.") \
		.set_title("Scientific Calculator") \
		.set_preview_factory(func(): return CalculatorWidgetScript.new("scientific"))
		
	# 4. 帮助目录
	var help = calc.add_command("help", "Help & Tips") \
		.set_description("Calculator implementation guide.") \
		.set_icon("Help")
		
	help.add_command("tip1", "Tip: Use Keyboard") \
		.set_description("You can type numbers") \
		.set_action(func(): print("Tip 1"))

func get_id() -> String:
	return "example.calculator"

func get_display_name() -> String:
	return "Calculator (Example)"
