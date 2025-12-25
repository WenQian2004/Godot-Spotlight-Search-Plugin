@tool
extends EditorInspectorPlugin

# 追踪组名
const TRACK_GROUP = "spotlight_tracked"

func _can_handle(object):
	# 仅处理 Node 类型及其子类
	return object is Node

func _parse_begin(object):
	if not object is Node: return
	var node = object as Node
	
	# 创建容器
	var container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 创建按钮
	var btn = Button.new()
	btn.custom_minimum_size.y = 28 # 稍微高一点
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 检查当前状态
	var is_tracked = node.is_in_group(TRACK_GROUP)
	_update_btn_style(btn, is_tracked)
	
	# 连接信号
	btn.pressed.connect(func():
		var current_state = node.is_in_group(TRACK_GROUP)
		if current_state:
			node.remove_from_group(TRACK_GROUP)
			# 如果该场景被保存，组信息也会被保存
			_update_btn_style(btn, false)
			print("[Spotlight] Untracked node: " + node.name)
		else:
			node.add_to_group(TRACK_GROUP, true) # persistent=true确保保存到场景文件
			_update_btn_style(btn, true)
			print("[Spotlight] Tracked node: " + node.name)
	)
	
	container.add_child(btn)
	add_custom_control(container)

func _update_btn_style(btn: Button, is_tracked: bool):
	var theme = EditorInterface.get_editor_theme()
	if is_tracked:
		btn.text = "Untrack Node"
		btn.icon = theme.get_icon("Favorites", "EditorIcons")
		# 红色调表示移除
		btn.modulate = Color(1, 0.7, 0.7)
	else:
		btn.text = "Track Node"
		btn.icon = theme.get_icon("Favorites", "EditorIcons")
		# 绿色调表示添加
		btn.modulate = Color(0.7, 1, 0.7)
