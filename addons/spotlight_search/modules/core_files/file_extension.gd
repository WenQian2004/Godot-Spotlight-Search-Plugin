@tool
extends SpotlightExtension

# 动态加载脚本引用
var FILE_RESULT_SCRIPT
var COMMAND_RESULT_SCRIPT
var FUZZY_SEARCH

const SCORE_BASE = 100


func _init():
	var base_dir = get_script().resource_path.get_base_dir()
	FILE_RESULT_SCRIPT = ResourceLoader.load(base_dir + "/file_result.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	# command_result.gd in ../core_commands/
	COMMAND_RESULT_SCRIPT = ResourceLoader.load(base_dir.get_base_dir() + "/core_commands/command_result.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	# Load fuzzy search module (use absolute path to ensure success)
	FUZZY_SEARCH = load("res://addons/spotlight_search/core/fuzzy_search.gd")
	
	if FUZZY_SEARCH == null:
		printerr("[Spotlight] Failed to load fuzzy_search.gd!")
	
	# Listen to filesystem changes
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)


func _on_filesystem_changed():
	call_deferred("_scan_project_files")

# 缓存所有文件路径
var _file_cache: Array[String] = []

# 定义支持的过滤器配置
# 格式: "-command": { "exts": [...], "desc": "...", "icon": "..." }
var FILTERS = {
	"-gdscript": { "exts": ["gd"], "desc": "Filter: GDScript files", "icon": "GDScript" },
	"-scene": { "exts": ["tscn", "scn"], "desc": "Filter: Scene files", "icon": "PackedScene" },
	"-image": { "exts": ["png", "jpg", "jpeg", "svg", "webp", "bmp", "tga"], "desc": "Filter: Image files", "icon": "ImageTexture" },
	"-resource": { "exts": ["tres", "res"], "desc": "Filter: Resource files", "icon": "Object" },
	"-config": { "exts": ["cfg", "ini", "json"], "desc": "Filter: Config files", "icon": "TextFile" }, # -config 也作为文件过滤器
	"-shader": { "exts": ["gdshader", "shader"], "desc": "Filter: Shader files", "icon": "Shader" }
}

func get_id() -> String: return "core.files"
func get_display_name() -> String: return "File Search"
func get_author() -> String: return "Godot Engine"

func _on_enable():
	call_deferred("_scan_project_files")

func _scan_project_files():
	_file_cache.clear()
	var excludes = SpotlightConfig.get_exclude_patterns()
	var allowed_exts = SpotlightConfig.get_allowed_extensions()
	_recursive_scan("res://", excludes, allowed_exts)
	print("[Spotlight] Indexed " + str(_file_cache.size()) + " files.")

func _recursive_scan(path: String, excludes: Array, allowed_exts: PackedStringArray):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				# 跳过 . 和 .. 目录
				if file_name == "." or file_name == "..":
					file_name = dir.get_next()
					continue
					
				var full_path = path.path_join(file_name)
				var skip = false
				
				# 检查目录是否应该被忽略
				# 支持多种匹配模式:
				# 1. "addons/" - 匹配任何路径中包含 addons/ 的目录
				# 2. ".git/" - 匹配任何路径中包含 .git/ 的目录  
				# 3. "res://addons/" - 完整路径匹配
				var check_path = full_path
				if not check_path.ends_with("/"):
					check_path += "/"
				
				for ex in excludes:
					var pattern = ex.strip_edges()
					if pattern.is_empty():
						continue
					# 支持完整路径匹配 (res://...) 或相对路径匹配
					if check_path.contains(pattern) or file_name + "/" == pattern:
						skip = true
						break
				
				if not skip:
					_recursive_scan(full_path, excludes, allowed_exts)
			else:
				var full_path = path.path_join(file_name)
				
				# 检查文件是否应该被忽略
				var skip = false
				for ex in excludes:
					var pattern = ex.strip_edges()
					if pattern.is_empty():
						continue
					if full_path.contains(pattern):
						skip = true
						break
				
				if not skip:
					var ext = file_name.get_extension().to_lower()
					# Check extension
					if ext in allowed_exts:
						_file_cache.append(full_path)
					
			file_name = dir.get_next()

# --- 核心查询逻辑 ---
func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = text.to_lower()
	var active_filters = []
	
	# 1. 检查 Context (上下文) 是否包含 active filters
	#    如果不为空，检查最后一个上下文是否是我们支持的过滤器
	if not context.is_empty():
		var last_item = context.back()
		# 检查这个 item 是否是我们的过滤器指令 (ID 格式: "filter.-command")
		var uid = last_item.get_unique_id() # e.g. "filter.-gdscript"
		if uid.begins_with("filter."):
			var cmd = uid.trim_prefix("filter.")
			if cmd in FILTERS:
				active_filters = FILTERS[cmd]["exts"]
		
		# 如果有上下文但不是我们的过滤器（比如是 -new），则 FileExtension 应该不工作
		if active_filters.is_empty():
			return []
	
	# 2. 如果没有上下文，处于顶层：检查是否需要提供过滤器建议
	if context.is_empty() and search_term.begins_with("-"):
		var parts = search_term.split(" ", false, 1)
		var cmd_part = parts[0]
		
		# 遍历支持的过滤器，提供建议
		for filter_cmd in FILTERS:
			# 如果输入完全匹配 (例如 "-gdscript")，或者输入了前缀 (例如 "-gd")
			if filter_cmd.begins_with(cmd_part):
				var info = FILTERS[filter_cmd]
				var title = filter_cmd
				
				# 创建过滤器建议项
				# 注意：is_category = true，这样选中它会变成 Tag/Breadcrumb
				var cmd_item = COMMAND_RESULT_SCRIPT.new(
					"filter." + filter_cmd,  # ID
					title,                   # Title
					info.desc,               # Description
					EditorInterface.get_editor_theme().get_icon(info.icon, "EditorIcons"), 
					Callable(),              # 无需回调，因为是 Category，UI 会自动进入
					true                     # is_category = true
				)
				cmd_item.tags = ["Official", "Filter"]
				results.append(cmd_item)
		
		if not results.is_empty():
			return results

	# 3. 执行文件搜索 (如果没有过滤器建议阻挡)
	#    如果在 Filter Context 下，active_filters 已经有值了
	
	var max_results = SpotlightConfig.get_max_results()
	var count = 0
	
	# 用于收集所有匹配项的临时数组
	var matched_items = []
	
	for path in _file_cache:
		var file_name = path.get_file()
		var ext = path.get_extension().to_lower()
		
		# 过滤器检查
		if not active_filters.is_empty():
			if not ext in active_filters:
				continue
		
		# 模糊匹配
		var score = 0
		if search_term.is_empty():
			# 空搜索：不做过滤，给个基础分
			# 但为了避免空搜索返回太多文件，通常空搜索不返回文件，除非是在 filters Context 下
			# 如果 context 不为空 (Filter mode)，允许空搜索显示所有符合扩展名的文件
			if not context.is_empty():
				score = SCORE_BASE
			else:
				continue # 顶层空搜索不返回文件
		else:
			var match_res = FUZZY_SEARCH.fuzzy_match(search_term, file_name)
			if not match_res.matched:
				continue
			score = match_res.score
			
		matched_items.append({
			"path": path,
			"score": score
		})

	# 排序 (分数高在前)
	matched_items.sort_custom(func(a, b): return a.score > b.score)
	
	# 截取前 max_results 个
	if matched_items.size() > max_results:
		matched_items = matched_items.slice(0, max_results)
		
	# 转换为 ResultItem
	for m in matched_items:
		var item = FILE_RESULT_SCRIPT.new(m.path)
		item.score = m.score
		# Add tags based on extension
		var ext = m.path.get_extension().to_lower()
		var type_tag = "File"
		if ext == "gd": type_tag = "GDScript"
		elif ext == "tscn" or ext == "scn": type_tag = "Scene"
		elif ext in ["png", "jpg", "svg", "webp"]: type_tag = "Image"
		elif ext in ["tres", "res"]: type_tag = "Resource"
		item.tags = ["File", type_tag]
		
		results.append(item)
			
	return results
