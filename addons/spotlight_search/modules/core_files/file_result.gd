@tool
extends SpotlightResultItem
class_name FileResult

## 用来表示“文件”的结果类型。
## 它负责定义文件的图标、拖拽数据和预览内容

var file_path: String

func _init(path: String):
	file_path = path
	title = path.get_file()
	type = ItemType.LEAF
	
	# 自动获取 Godot 编辑器内部图标
	var editor = EditorInterface.get_editor_theme()
	if editor:
		var ext = path.get_extension().to_lower()
		match ext:
			"gd":
				icon = editor.get_icon("GDScript", "EditorIcons")
			"tscn":
				icon = editor.get_icon("PackedScene", "EditorIcons")
			"tres", "res":
				icon = editor.get_icon("Object", "EditorIcons")
			"shader", "gdshader":
				icon = editor.get_icon("Shader", "EditorIcons")
			"png", "jpg", "jpeg", "svg", "webp":
				icon = editor.get_icon("ImageTexture", "EditorIcons")
			"wav", "ogg", "mp3":
				icon = editor.get_icon("AudioStreamPlayer", "EditorIcons")
			"ttf", "otf":
				icon = editor.get_icon("Font", "EditorIcons")
			"json", "cfg", "ini", "txt", "md":
				icon = editor.get_icon("TextFile", "EditorIcons")
			"glb", "gltf", "obj", "fbx":
				icon = editor.get_icon("Mesh", "EditorIcons")
			_:
				icon = editor.get_icon("File", "EditorIcons")

# --- 核心：定义拖拽数据 ---
func get_drag_data() -> Variant:
	# Godot 编辑器识别的拖拽格式：
	# { "type": "files", "files": ["res://..."] }
	return {
		"type": "files",
		"files": [file_path]
	}

# --- 核心：定义预览类型 ---
func get_preview_type() -> PreviewType:
	# 统一使用 STANDARD_FILE，以保证风格一致
	return PreviewType.STANDARD_FILE

# --- 核心：定义预览内容 ---
func get_preview_content() -> Dictionary:
	var content = {}
	content["text"] = file_path # 描述显示完整路径
	
	var ext = file_path.get_extension().to_lower()
	
	# 文本类型文件显示代码预览
	if ext in ["gd", "shader", "gdshader", "json", "cfg", "ini", "txt", "md"]:
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var text = ""
			var max_preview_length = SpotlightConfig.get_max_preview_length()
			
			while file.get_position() < max_preview_length and not file.eof_reached():
				text += file.get_line() + "\n"
				
			if text.length() > max_preview_length:
				text = text.left(max_preview_length) + "..."
				
			content["code"] = text
	
	# 图片类型显示缩略图
	elif ext in ["png", "jpg", "jpeg", "svg", "webp"]:
		var tex = load(file_path) as Texture2D
		if tex:
			content["image_texture"] = tex
			
	# 场景类型请求生成缩略图
	elif ext == "tscn":
		content["request_thumbnail"] = true
	
	return content

# --- 核心：执行逻辑 ---
func execute():
	var ext = file_path.get_extension().to_lower()
	
	# 先让文件系统导航到对应位置
	var fs_dock = EditorInterface.get_file_system_dock()
	if fs_dock:
		fs_dock.navigate_to_path(file_path)
	
	# 场景文件 - 使用 open_scene_from_path，然后切换到 2D/3D 视图
	if ext == "tscn":
		EditorInterface.open_scene_from_path(file_path)
		# 智能检测根节点类型，切换 2D 或 3D 视图
		var packed_scene = load(file_path)
		if packed_scene and packed_scene is PackedScene:
			var state = packed_scene.get_state()
			if state and state.get_node_count() > 0:
				var root_type = state.get_node_type(0)
				if ClassDB.is_parent_class(root_type, "Node3D"):
					EditorInterface.set_main_screen_editor("3D")
				elif ClassDB.is_parent_class(root_type, "Control") or ClassDB.is_parent_class(root_type, "Node2D"):
					EditorInterface.set_main_screen_editor("2D")
				else:
					# 默认保持当前或切到 2D
					EditorInterface.set_main_screen_editor("2D")
		else:
			EditorInterface.set_main_screen_editor("2D")
	# 脚本文件 - 直接编辑
	elif ext == "gd":
		var script = load(file_path)
		if script:
			EditorInterface.edit_script(script)
			# 切换到脚本编辑器
			EditorInterface.set_main_screen_editor("Script")
	# md 文件 - 尝试在脚本编辑器中打开
	elif ext == "md":
		# Godot 4.x 可以用脚本编辑器打开 md 文件
		var script_editor = EditorInterface.get_script_editor()
		if script_editor:
			# 尝试加载为文本资源
			var res = load(file_path)
			if res:
				EditorInterface.edit_resource(res)
				EditorInterface.set_main_screen_editor("Script")
			else:
				# 如果无法加载，用系统打开
				OS.shell_open(ProjectSettings.globalize_path(file_path))
		else:
			OS.shell_open(ProjectSettings.globalize_path(file_path))
	# 下列文本文件不是 Resource，不能用 load()，改用系统打开
	elif ext in ["txt", "html", "cfg", "ini", "yml", "yaml", "xml"]:
		OS.shell_open(ProjectSettings.globalize_path(file_path))
	# json 文件 - 尝试在脚本编辑器中打开
	elif ext == "json":
		var res = load(file_path)
		if res:
			EditorInterface.edit_resource(res)
			EditorInterface.set_main_screen_editor("Script")
		else:
			OS.shell_open(ProjectSettings.globalize_path(file_path))
	# 其他资源 - 使用 edit_resource
	else:
		if ResourceLoader.exists(file_path):
			var res = load(file_path)
			if res:
				EditorInterface.edit_resource(res)
		else:
			# 无法加载的文件，尝试用系统打开
			OS.shell_open(ProjectSettings.globalize_path(file_path))
	
	#print("Opening file: " + file_path)

func get_unique_id() -> String:
	return "file://" + file_path
