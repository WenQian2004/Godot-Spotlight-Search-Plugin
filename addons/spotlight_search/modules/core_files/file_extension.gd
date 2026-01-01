@tool
extends SpotlightSimpleExtension

# --- 文件搜索扩展 (Refactored) ---

# 动态加载引用
var FILE_RESULT_SCRIPT
var FUZZY_SEARCH

var FILTERS = {
	"-gdscript": { "exts": ["gd"], "desc": "Filter: GDScript files", "icon": "GDScript" },
	"-scene": { "exts": ["tscn", "scn"], "desc": "Filter: Scene files", "icon": "PackedScene" },
	"-image": { "exts": ["png", "jpg", "jpeg", "svg", "webp", "bmp", "tga"], "desc": "Filter: Image files", "icon": "ImageTexture" },
	"-resource": { "exts": ["tres", "res"], "desc": "Filter: Resource files", "icon": "Object" },
	"-config": { "exts": ["cfg", "ini", "json"], "desc": "Filter: Config files", "icon": "TextFile" },
	"-shader": { "exts": ["gdshader", "shader"], "desc": "Filter: Shader files", "icon": "Shader" }
}

# 缓存所有文件路径
var _file_cache: Array[String] = []

func _init():
	var base_dir = get_script().resource_path.get_base_dir()
	FILE_RESULT_SCRIPT = ResourceLoader.load(base_dir + "/file_result.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	FUZZY_SEARCH = load("res://addons/spotlight_search/core/fuzzy_search.gd")
	
	if FUZZY_SEARCH == null:
		printerr("[Spotlight] Failed to load fuzzy_search.gd!")
	
	# 动态注册过滤器指令
	for cmd_key in FILTERS:
		var info = FILTERS[cmd_key]
		# 使用闭包捕获 exts
		var provider = func(query: String) -> Array[SpotlightResultItem]:
			return _search_files(query, info.exts)
			
		add_command(cmd_key, info.desc) \
			.set_icon(info.icon) \
			.set_tags(["Official", "Filter"]) \
			.set_dynamic_provider(provider)

	# 监听文件系统变化
	if Engine.is_editor_hint():
		var fs = EditorInterface.get_resource_filesystem()
		if not fs.filesystem_changed.is_connected(_on_filesystem_changed):
			fs.filesystem_changed.connect(_on_filesystem_changed)
		_on_enable()

func get_id() -> String: return "core.files"
func get_display_name() -> String: return "File Search"
func get_author() -> String: return "Godot Engine"

func _on_enable():
	call_deferred("_scan_project_files")

func _on_filesystem_changed():
	call_deferred("_scan_project_files")

# --- 核心查询逻辑重写 ---

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	# 1. 优先使用基类逻辑处理指令 (例如 -gdscript)
	var results = super.query(text, context)
	
	# 2. 如果没有匹配到指令，且不是以 "-" 开头（或者是空），则进行全局文件搜索
	if context.is_empty():
		if not text.begins_with("-"):
			results.append_array(_search_files(text, []))
			
	return results

# --- 文件搜索实现 ---

func _search_files(query: String, filter_exts: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = query.to_lower()
	var max_results = SpotlightConfig.get_max_results()
	
	var matched_items = []
	
	for path in _file_cache:
		var file_name = path.get_file()
		var ext = path.get_extension().to_lower()
		
		# 过滤器检查
		if not filter_exts.is_empty():
			if not ext in filter_exts:
				continue
		
		# 模糊匹配
		var score = 0
		if search_term.is_empty():
			# 如果有过滤器，空搜索显示所有；否则（全局搜索）不显示
			if not filter_exts.is_empty():
				score = 100
			else:
				continue 
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

# --- 文件扫描逻辑 (复用) ---

func _scan_project_files():
	_file_cache.clear()
	var excludes = SpotlightConfig.get_exclude_patterns()
	var allowed_exts = SpotlightConfig.get_allowed_extensions()
	_recursive_scan("res://", excludes, allowed_exts)
	#print("[Spotlight] Indexed " + str(_file_cache.size()) + " files.")

func _recursive_scan(path: String, excludes: Array, allowed_exts: PackedStringArray):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name == "." or file_name == "..":
					file_name = dir.get_next()
					continue
					
				var full_path = path.path_join(file_name)
				var skip = false
				var check_path = full_path
				if not check_path.ends_with("/"):
					check_path += "/"
				
				for ex in excludes:
					var pattern = ex.strip_edges()
					if pattern.is_empty(): continue
					if check_path.contains(pattern) or file_name + "/" == pattern:
						skip = true
						break
				
				if not skip:
					_recursive_scan(full_path, excludes, allowed_exts)
			else:
				var full_path = path.path_join(file_name)
				var skip = false
				for ex in excludes:
					var pattern = ex.strip_edges()
					if pattern.is_empty(): continue
					if full_path.contains(pattern):
						skip = true
						break
				
				if not skip:
					var ext = file_name.get_extension().to_lower()
					if ext in allowed_exts:
						_file_cache.append(full_path)
					
			file_name = dir.get_next()
