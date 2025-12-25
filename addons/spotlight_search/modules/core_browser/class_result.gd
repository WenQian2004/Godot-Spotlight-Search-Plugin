@tool
extends SpotlightResultItem
class_name ClassBrowserResult

## 类浏览器结果项 - 用于显示引擎类、属性和方法

enum MemberType { CLASS, PROPERTY, METHOD, SIGNAL }

var class_name_str: String = ""        # 所属类名
var member_name: String = ""           # 成员名称 (属性/方法)
var member_type: MemberType = MemberType.CLASS
var return_type: String = ""           # 返回类型 (用于方法)
var signature: String = ""             # 完整签名 (用于方法)
var parent_class: String = ""          # 父类名
var child_classes: Array[String] = []  # 子类列表 (仅前5个)
var total_children: int = 0            # 总子类数量
var command_path: String = ""          # 完整命令路径 (用于导航)
var auto_complete_text: String = ""    # 自动补全文本

func _init(
	p_class_name: String = "", 
	p_member_name: String = "", 
	p_member_type: MemberType = MemberType.CLASS,
	p_command_path: String = ""
):
	class_name_str = p_class_name
	member_name = p_member_name
	member_type = p_member_type
	command_path = p_command_path
	
	# 设置基础属性
	match member_type:
		MemberType.CLASS:
			title = p_class_name
			description = "Engine Class"
			type = ItemType.CATEGORY  # 类可以展开查看成员
			icon = _get_class_icon(p_class_name)
			auto_complete_text = command_path
		MemberType.PROPERTY:
			title = p_member_name
			description = "Property (%s)" % return_type
			type = ItemType.LEAF
			icon = EditorInterface.get_editor_theme().get_icon("MemberProperty", "EditorIcons")
			auto_complete_text = p_member_name
		MemberType.METHOD:
			title = p_member_name + "()"
			description = "Method → " + return_type
			type = ItemType.LEAF
			icon = EditorInterface.get_editor_theme().get_icon("MemberMethod", "EditorIcons")
			auto_complete_text = signature if not signature.is_empty() else p_member_name + "()"
		MemberType.SIGNAL:
			title = p_member_name
			description = "Signal"
			type = ItemType.LEAF
			icon = EditorInterface.get_editor_theme().get_icon("MemberSignal", "EditorIcons")
			auto_complete_text = p_member_name

func _get_class_icon(cls_name: String) -> Texture2D:
	var theme = EditorInterface.get_editor_theme()
	if theme.has_icon(cls_name, "EditorIcons"):
		return theme.get_icon(cls_name, "EditorIcons")
	return theme.get_icon("Object", "EditorIcons")

func get_preview_type() -> PreviewType:
	if member_type == MemberType.CLASS:
		return PreviewType.STANDARD_DESC
	return PreviewType.STANDARD_DESC

func get_preview_content() -> Dictionary:
	var content = {}
	
	match member_type:
		MemberType.CLASS:
			var desc_lines = []
			desc_lines.append("Class: " + class_name_str)
			if not parent_class.is_empty():
				desc_lines.append("Inherits: " + parent_class)
			if total_children > 0:
				desc_lines.append("Children: %d classes" % total_children)
			content["text"] = "\n".join(desc_lines)
			
		MemberType.PROPERTY:
			content["text"] = "%s.%s\nType: %s" % [class_name_str, member_name, return_type]
			
		MemberType.METHOD:
			content["text"] = "%s.%s\nSignature: %s\nReturns: %s" % [class_name_str, member_name, signature, return_type]
			
		MemberType.SIGNAL:
			content["text"] = "%s.%s\nSignal" % [class_name_str, member_name]
	
	return content

func execute():
	# 对于类：复制类名到剪贴板
	# 对于成员：复制成员名（或完整签名）到剪贴板
	var text_to_copy = auto_complete_text
	DisplayServer.clipboard_set(text_to_copy)
	print("[Spotlight] Copied to clipboard: " + text_to_copy)

func get_unique_id() -> String:
	if member_type == MemberType.CLASS:
		return "class." + class_name_str
	return "class.%s.%s" % [class_name_str, member_name]

func get_drag_data() -> Variant:
	# 支持拖拽：将成员名称作为文本拖拽
	return {
		"type": "text",
		"text": auto_complete_text
	}
