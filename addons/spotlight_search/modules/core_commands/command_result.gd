@tool
extends SpotlightResultItem
class_name CommandResult

var command_id: String
var command_callback: Callable # 实际执行的函数

func _init(p_id: String, p_title: String, p_desc: String, p_icon: Texture2D, p_callback: Callable, p_is_category: bool = false):
	command_id = p_id
	title = p_title
	description = p_desc # 存储描述
	icon = p_icon
	command_callback = p_callback
	type = ItemType.LEAF # 默认是叶子节点
	if p_is_category:
		type = ItemType.CATEGORY

func get_preview_content() -> Dictionary:
	# 命令通常显示描述文本
	return { "text": description }

func execute():
	if command_callback.is_valid():
		command_callback.call()

func get_unique_id() -> String:
	return command_id
