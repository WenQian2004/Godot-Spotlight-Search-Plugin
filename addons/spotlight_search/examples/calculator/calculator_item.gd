@tool
extends SpotlightResultItem # 继承核心结果类

# 这是一个自定义的 Result Item
# 用于承载计算器特有的逻辑和预览

# 预加载的 UI 组件
const CALCULATOR_WIDGET = preload("res://addons/spotlight_search/examples/calculator/calculator_widget.gd")

var mode: String = "standard"

# --- 构造函数 ---
func _init(p_title: String, p_desc: String, p_mode: String):
	title = p_title
	description = p_desc
	mode = p_mode
	
	# 设置图标 (使用内置图标)
	if mode == "standard":
		icon = EditorInterface.get_editor_theme().get_icon("Edit", "EditorIcons")
	else:
		icon = EditorInterface.get_editor_theme().get_icon("GraphNode", "EditorIcons")

# --- 核心：重写预览类型 ---
# 告诉 Spotlight 我们要使用自定义预览
func get_preview_type() -> PreviewType:
	if mode == "standard":
		return PreviewType.CUSTOM
	else:
		return PreviewType.STANDARD_DESC

# --- 核心：创建自定义预览控件 ---
# 仅当 preview_type 为 CUSTOM 时调用
func create_custom_preview() -> Control:
	if mode == "standard":
		return CALCULATOR_WIDGET.new()
	return null

# --- 核心：重写唯一 ID ---
# 确保 ID 唯一，以便正确处理上下文 (Breadcrumbs)
func get_unique_id() -> String:
	return "calc." + mode

# --- 执行逻辑 ---
func execute():
	print("Executing Calculator Mode: ", mode)
	# 在这里可以添加进入下一级或其他逻辑
