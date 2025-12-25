@tool
extends SpotlightExtension

# 这是一个使用 Spotlight Search 的扩展开发教程示例
# 实现了：
# 1. 自定义指令 (-calc)
# 2. 多级嵌套 (Category)
# 3. 自定义侧边栏 UI (Custom Preview)

var CALCULATOR_ITEM
var COMMAND_RESULT
var FUZZY_SEARCH

const SCORE_BASE = 100


func _init():
	var base_dir = get_script().resource_path.get_base_dir()
	# 动态加载同目录下的依赖
	CALCULATOR_ITEM = load(base_dir + "/calculator_item.gd")
	# 动态加载核心依赖 (假定核心在固定位置，或者通过相对路径查找)
	# 为了演示健壮性，这里我们假设 Core 就在 ../../../modules/core_commands/command_result.gd
	# 基础路径: res://addons/spotlight_search/examples/calculator
	# 目标: res://addons/spotlight_search/modules/core_commands/command_result.gd
	# 向上 3 级 -> addons/spotlight_search -> modules/core_commands/command_result.gd
	var root_dir = base_dir.get_base_dir().get_base_dir()
	COMMAND_RESULT = load(root_dir + "/modules/core_commands/command_result.gd")
	FUZZY_SEARCH = load("res://addons/spotlight_search/core/fuzzy_search.gd")


func get_id() -> String:
	return "example.calculator"

func get_display_name() -> String:
	return "Calculator (Example)"

# --- 核心查询接口 ---
func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search = text.to_lower()
	
	# === 第一层：顶层指令 ===
	# 如果没有上下文，检查是否匹配 "-calc"
	if context.is_empty():
		var match_res = FUZZY_SEARCH.fuzzy_match(search, "-calc")
		if search == "" or match_res.matched:
			# 使用 CommandResult 来创建一个“入口”
			# is_category = true 表示选中它会进入下一级
			var entry = COMMAND_RESULT.new(
				"cmd.calc",              # ID
				"-calc",                 # Title
				"Calculator Tools",      # Description
				EditorInterface.get_editor_theme().get_icon("Edit", "EditorIcons"),
				Callable(),              # 回调为空，因为它是目录
				true                     # is_category = True!
			)
			entry.score = match_res.score if search != "" else SCORE_BASE
			results.append(entry)
			
	# === 第二层：进入了 -calc ===
	elif not context.is_empty():
		var last = context.back()
		
		# 检查我们是否在 "-calc" 内部
		# 注意：这里我们检查 last 的 ID。所有的 SpotlightResultItem 都有 get_unique_id()
		if last.get_unique_id() == "cmd.calc":
			
			# 添加子指令：标准计算器
			# CalculatorItem 内部定义了 mode="standard" 会显示 UI
			var std_calc = CALCULATOR_ITEM.new(
				"Standard Calculator",
				"Interactive calculator in side panel",
				"standard"
			)
			var match_std = FUZZY_SEARCH.fuzzy_match(search, "Standard Calculator")
			if search == "" or match_std.matched:
				std_calc.score = match_std.score if search != "" else SCORE_BASE
				results.append(std_calc)
				
			# 添加子指令：科学计算器 (只是个占位符示例)
			var sci_calc = CALCULATOR_ITEM.new(
				"Scientific Calculator",
				"Advanced math functions (Placeholder)",
				"scientific"
			)
			var match_sci = FUZZY_SEARCH.fuzzy_match(search, "Scientific Calculator")
			if search == "" or match_sci.matched:
				sci_calc.score = match_sci.score if search != "" else SCORE_BASE
				results.append(sci_calc)
			
			# 添加一个更深层级的目录示例
			var tools_cat = COMMAND_RESULT.new(
				"cmd.calc.help",
				"Help & Tips",
				"Learn how to use",
				EditorInterface.get_editor_theme().get_icon("Help", "EditorIcons"),
				Callable(),
				true # 也是目录
			)
			var match_help = FUZZY_SEARCH.fuzzy_match(search, "Help & Tips")
			if search == "" or match_help.matched:
				tools_cat.score = match_help.score if search != "" else SCORE_BASE
				results.append(tools_cat)
				
		# === 第三层：进入了 Help ===
		elif last.get_unique_id() == "cmd.calc.help":
			var tip1 = COMMAND_RESULT.new(
				"cmd.tip1", "Tip: Use Keyboard", "You can type numbers", null, func(): print("Tip 1"), false
			)
			results.append(tip1)

	return results
