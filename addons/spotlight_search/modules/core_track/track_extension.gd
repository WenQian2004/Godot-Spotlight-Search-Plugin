@tool
extends SpotlightSimpleExtension

# --- 场景节点跟踪扩展 ---

const TRACK_GROUP = "spotlight_tracked"

func _init():
	# 主指令: -track
	var track = add_command("-track", "Scene Node Tracker") \
		.set_icon("Search") \
		.set_tags(["Official", "Command"])
	
	# 子指令: all (显示所有节点)
	track.add_command("all", "List All Scene Nodes") \
		.set_icon("ListSelect") \
		.set_dynamic_provider(_provide_scene_nodes)
		
	# 子指令: find (显示被跟踪/收藏的节点)
	track.add_command("find", "Find Tracked/Favorite Nodes") \
		.set_icon("Favorites") \
		.set_dynamic_provider(_provide_tracked_nodes)

func get_id() -> String:
	return "core.track"

func get_display_name() -> String:
	return "Scene Node Tracker"
	
func get_author() -> String:
	return "Godot Engine"

func get_version() -> String:
	return "2.0.0"

# --- 动态提供者 ---

func _provide_scene_nodes(query: String) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return []
		
	# 递归获取所有节点
	var all_nodes = []
	_collect_nodes(root, all_nodes)
	
	for node in all_nodes:
		if query.is_empty() or node.name.to_lower().contains(query.to_lower()):
			var item = TrackSimpleItem.new()
			item.title = node.name
			item.description = str(root.get_path_to(node))
			item.target_node_path = root.get_path_to(node)
			
			var class_icon = node.get_class()
			if EditorInterface.get_editor_theme().has_icon(class_icon, "EditorIcons"):
				item.icon = EditorInterface.get_editor_theme().get_icon(class_icon, "EditorIcons")
			else:
				item.icon = EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
				
			item.score = 100
			
			# 点击选中节点
			item.set_execute_callback(func(): 
				EditorInterface.get_selection().clear()
				EditorInterface.get_selection().add_node(node)
				print("[Spotlight] Selected node: ", node.name)
			)
			results.append(item)
			
	return results

func _collect_nodes(node: Node, list: Array):
	list.append(node)
	for child in node.get_children():
		_collect_nodes(child, list)

func _provide_tracked_nodes(query: String) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return []
		
	# 获取所有分组中的节点
	var nodes = root.get_tree().get_nodes_in_group(TRACK_GROUP)
	
	for node in nodes:
		# 确保节点属于当前场景
		if not (node == root or root.is_ancestor_of(node)):
			continue
			
		if query.is_empty() or node.name.to_lower().contains(query.to_lower()):
			var item = TrackSimpleItem.new()
			item.title = node.name
			item.description = str(root.get_path_to(node))
			item.target_node_path = root.get_path_to(node)
			
			var class_icon = node.get_class()
			if EditorInterface.get_editor_theme().has_icon(class_icon, "EditorIcons"):
				item.icon = EditorInterface.get_editor_theme().get_icon(class_icon, "EditorIcons")
			else:
				item.icon = EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
				
			item.score = 100
			item.tags = ["Tracked"]
			
			# 点击选中节点
			item.set_execute_callback(func(): 
				EditorInterface.get_selection().clear()
				EditorInterface.get_selection().add_node(node)
			)
			results.append(item)
			
	return results

# --- 自定义 Item 类 (支持拖拽) ---
class TrackSimpleItem extends SimpleResultItem:
	var target_node_path: NodePath
	
	func get_drag_data() -> Variant:
		# 返回 GDScript 友好的节点路径引用 ($Path)
		var p_str = str(target_node_path)
		var text = "$" + p_str
		# 处理空格
		if " " in p_str:
			text = '$"%s"' % p_str
			
		return text
