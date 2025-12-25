@tool
extends Node

# 存储所有扩展实例
var _extensions: Array[SpotlightExtension] = []
# 存储被禁用的扩展 ID 列表 (不再使用，改用 ConfigManager)
var _disabled_ids: Array = []

const HISTORY_SETTING = "spotlight_search/state/history"
const MAX_HISTORY = 20

# 搜索历史
var _history: Array[String] = []

func _ready():
	_load_history()
	
	# 动态获取插件根目录 (core的上级目录)
	var base_path = get_script().resource_path.get_base_dir().get_base_dir()
	
	# 注册默认扩展 (这里只是实例化，是否启用由内部逻辑判断)
	register_extension(load(base_path + "/modules/core_files/file_extension.gd").new())
	register_extension(load(base_path + "/modules/core_commands/command_extension.gd").new())
	# 注册 Class Browser 扩展
	register_extension(load(base_path + "/modules/core_browser/class_browser_extension.gd").new())
	# 注册 Track Extension
	register_extension(load(base_path + "/modules/core_track/track_extension.gd").new())
	

	# 注册外部扩展 (动态路径)
	var external_paths = SpotlightConfig.get_external_extensions()
	for path in external_paths:
		_load_and_register_external(path)

func _load_and_register_external(path: String):
	if FileAccess.file_exists(path):
		var script = load(path)
		if script and script.can_instantiate():
			var instance = script.new()
			if instance is SpotlightExtension:
				register_extension(instance)
				print("[Spotlight] Loaded external extension: " + path)
			else:
				printerr("[Spotlight] Script at " + path + " does not extend SpotlightExtension. Removing from config.")
				SpotlightConfig.remove_external_extension(path)
		else:
			printerr("[Spotlight] Failed to load extension script: " + path)
	else:
		printerr("[Spotlight] External extension not found: " + path + ". Removing from config.")
		SpotlightConfig.remove_external_extension(path)


func register_extension(ext: SpotlightExtension):
	if ext not in _extensions:
		_extensions.append(ext)
		# 如果 ID 不在禁用列表中，则启用
		if not is_extension_disabled(ext.get_id()):
			ext._on_enable()
		print("[Spotlight] Registered: " + ext.get_id())

func unregister_extension(script_path: String):
	var to_remove = null
	for ext in _extensions:
		var path = ext.get_script().resource_path
		if path == script_path:
			to_remove = ext
			break
	
	if to_remove:
		to_remove._on_disable()
		_extensions.erase(to_remove)
		print("[Spotlight] Unregistered: " + to_remove.get_id())
	else:
		print("[Spotlight] Extension not found for unregister: " + script_path)

func get_all_extensions() -> Array[SpotlightExtension]:
	return _extensions

# --- 状态管理 ---

func is_extension_disabled(id: String) -> bool:
	# 使用 ConfigManager 来检查扩展是否启用
	return not SpotlightConfig.is_extension_enabled(id)

func set_extension_disabled(id: String, disabled: bool):
	SpotlightConfig.set_extension_enabled(id, not disabled)
	_notify_extension_status(id, not disabled)

func _notify_extension_status(id: String, enabled: bool):
	for ext in _extensions:
		if ext.get_id() == id:
			if enabled:
				ext._on_enable()
			else:
				ext._on_disable()
			break

# --- 核心查询 (带过滤与自适应排序) ---

func query_all(text: String, context: Array) -> Array[SpotlightResultItem]:
	# 0. 零查询处理 (Adaptive Ranking)
	if text.strip_edges().is_empty() and context.is_empty():
		return _get_zero_query_results()

	var combined: Array[SpotlightResultItem] = []
	
	# 判断当前查询模式 (指令模式 vs 常规模式)
	var is_command_mode = text.begins_with("-")
	# 如果有上下文，通常交给相应的 Extension 处理（通常 Command 会有上下文），
	# 但为了防止 FileExtension 在有上下文时也被调用
	var has_context = not context.is_empty()
	
	for ext in _extensions:
		# 1. 禁用检查
		if is_extension_disabled(ext.get_id()):
			continue
			
		var ext_id = ext.get_id()
		
		# 2. 模式过滤
		# 命令类扩展 (core.commands 和第三方命令扩展) 只在命令模式或有上下文时工作
		if ext_id == "core.files":
			# 文件扩展：允许在 Command Mode 下运行，以支持 -gdscript 等过滤器
			pass
		else:
			# 其他扩展（命令类）：只有在 Command Mode 或者已经有 Context 时才工作
			if not is_command_mode and not has_context:
				continue
		
		# 3. 执行查询
			
		var results = ext.query(text, context)
		if results:
			combined.append_array(results)
			
	# 根据分数排序 (高分在前)
	combined.sort_custom(func(a, b): return a.score > b.score)
	return combined


# 获取所有已解析的收藏项（供 UI 调用）
func get_all_favorites_as_items() -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var favorites = SpotlightFavoritesManager.get_all_favorites()
	
	for id in favorites:
		if id.begins_with("file://"):
			var path = id.substr(7)
			if not FileAccess.file_exists(path): continue
			
			var item = _create_file_item(path)
			item.score = 1000
			results.append(item)
		else:
			# 解析非文件类型的 ID
			for ext in _extensions:
				if is_extension_disabled(ext.get_id()): continue
				var item = ext.resolve_item(id)
				if item:
					item.score = 1000
					results.append(item)
					break
	return results

func _get_zero_query_results() -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var added_ids = {}
	
	# 1. 移除初始页面的收藏显示
	# (用户要求收藏仅在 Shift+Down 页面显示)
	
	# 2. 最近历史 (History) -> Score 500

	for id in _history:
		if id in added_ids: continue
		
		# 处理文件历史记录
		# 假设历史记录 ID 为文件路径或 file://URI
		var path = id
		if id.begins_with("file://"):
			path = id.substr(7)
			
		if FileAccess.file_exists(path):
			var item = _create_file_item(path)
			item.score = 500
			results.append(item)
			added_ids[id] = true
	
	# 3. 补充推荐 (Scenes/Scripts)
	# 若当前结果不足 max_results，则从缓存中补充常用的场景或脚本文件
	var max_results = SpotlightConfig.get_max_results()
	if results.size() < max_results:
		var all_files = []
		# 为了性能，这里只从 FileExtension 的缓存里拿
		for ext in _extensions:
			if ext.get_id() == "core.files":
				# 从 core.files 扩展获取文件缓存
				# TODO：这是一个临时约定的接口，后续应考虑通过 Extension API 正式暴露
				if "get_all_files" in ext:
					all_files = ext.call("get_all_files")
				elif "_file_cache" in ext:
					all_files = ext._file_cache
				break
		
		# 优先显示场景和脚本文件
		var prioritized_files = []
		var other_files = []
		for path in all_files:
			var ext_name = path.get_extension().to_lower()
			if ext_name in ["tscn", "scn", "gd"]:
				prioritized_files.append(path)
			else:
				other_files.append(path)
		
		# 合并：场景/脚本优先
		var sorted_files = prioritized_files + other_files
		
		# 补充文件到结果列表（最多补充到 max_results）
		var remaining_slots = max_results - results.size()
		var count = 0
		for path in sorted_files:
			if count >= remaining_slots: break
			# 统一使用 file:// 前缀的 ID 格式来检查
			var file_id = "file://" + path
			if file_id in added_ids: continue
			
			var item = _create_file_item(path)
			item.score = 100
			results.append(item)
			added_ids[file_id] = true
			count += 1
		
	return results
	
func _create_file_item(path: String) -> SpotlightResultItem:
	# 直接使用全局类 FileResult
	return FileResult.new(path)


# --- 历史记录管理 ---

func add_history(path: String):
	if path.strip_edges().is_empty(): return
	
	if path in _history:
		_history.erase(path)
	_history.push_front(path)
	
	if _history.size() > MAX_HISTORY:
		_history.resize(MAX_HISTORY)
		
	_save_history()

func get_history() -> Array[String]:
	return _history

func _save_history():
	ProjectSettings.set_setting(HISTORY_SETTING, _history)
	ProjectSettings.save()

func _load_history():
	if ProjectSettings.has_setting(HISTORY_SETTING):
		var val = ProjectSettings.get_setting(HISTORY_SETTING)
		if val is Array:
			_history.assign(val)
	else:
		ProjectSettings.set_setting(HISTORY_SETTING, [])
		ProjectSettings.save()

# --- 配置管理 (Exclude Patterns) ---
# 现在使用 SpotlightConfig，这个方法保留用于向后兼容
func get_exclude_patterns() -> PackedStringArray:
	return SpotlightConfig.get_exclude_patterns()

# --- 持久化 (Project Settings) ---

func _save_settings():
	# 不再需要，ConfigManager 会自动保存
	pass

func _load_settings():
	# 不再需要，ConfigManager 会自动处理
	pass
