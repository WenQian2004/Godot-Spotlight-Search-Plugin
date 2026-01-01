@tool
extends SpotlightExtension
class_name SpotlightSimpleExtension

## 简化版扩展基类
## 通过声明式 API 快速注册命令，自动处理模糊搜索和上下文

# --- 内部数据结构 ---
class CommandDefinition:
	var id: String
	var keyword: String
	var title: String
	var description: String
	var icon: Texture2D
	var callback: Callable
	var is_category: bool = false
	var sub_commands: Array[CommandDefinition] = []
	var tags: Array = []
	var preview_type = SpotlightResultItem.PreviewType.STANDARD_DESC
	var custom_preview_script: Script = null # 用于 CUSTOM 预览
	var custom_preview_factory: Callable = Callable() # 优先于 script 使用
	var dynamic_provider: Callable = Callable() # 动态结果提供者 func(query) -> Array[SpotlightResultItem]
	
	func _init(p_keyword: String, p_desc: String):
		keyword = p_keyword
		# 默认 ID 为 keyword (去掉前缀 -)
		id = keyword.trim_prefix("-")
		title = keyword
		description = p_desc
	
	# --- 链式配置 API ---
	
	func set_title(p_title: String) -> CommandDefinition:
		title = p_title
		return self
		
	func set_description(p_desc: String) -> CommandDefinition:
		description = p_desc
		return self
		
	func set_icon(name_or_texture) -> CommandDefinition:
		if name_or_texture is String:
			if Engine.is_editor_hint():
				icon = EditorInterface.get_editor_theme().get_icon(name_or_texture, "EditorIcons")
		elif name_or_texture is Texture2D:
			icon = name_or_texture
		return self
	
	func set_action(cb: Callable) -> CommandDefinition:
		callback = cb
		return self
		
	func set_tags(p_tags: Array) -> CommandDefinition:
		tags = p_tags
		return self
		
	func set_preview_custom(script: Script) -> CommandDefinition:
		preview_type = SpotlightResultItem.PreviewType.CUSTOM
		custom_preview_script = script
		return self
		
	func set_preview_factory(factory: Callable) -> CommandDefinition:
		preview_type = SpotlightResultItem.PreviewType.CUSTOM
		custom_preview_factory = factory
		return self
		
	func set_dynamic_provider(provider: Callable) -> CommandDefinition:
		dynamic_provider = provider
		is_category = true # 有 Dynamic Provider 的也视为 Category (进入后显示内容)
		return self
	
	# 添加子命令
	func add_command(p_keyword: String, p_desc: String) -> CommandDefinition:
		is_category = true # 有子命令自动变为 Category
		var cmd = CommandDefinition.new(p_keyword, p_desc)
		# 子命令 ID 默认加上父级前缀
		cmd.id = id + "." + cmd.id
		sub_commands.append(cmd)
		return cmd

# --- 扩展主逻辑 ---

var _root_commands: Array[CommandDefinition] = []

# 子类在 _init() 中调用此方法注册命令
func add_command(keyword: String, description: String) -> CommandDefinition:
	var cmd = CommandDefinition.new(keyword, description)
	# 自动加上扩展 ID 前缀，防止冲突
	cmd.id = get_id() + "." + cmd.id
	_root_commands.append(cmd)
	return cmd

# --- 自动实现 query ---

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = text.to_lower()
	
	# 1. 确定当前搜索范围 (Root 还是某个子命令)
	var target_list = _root_commands
	var active_def: CommandDefinition = null
	
	if not context.is_empty():
		# 遍历 context 找到对应的 CommandDefinition
		var parent_id = context.back().get_unique_id()
		var found = _find_command_by_id(_root_commands, parent_id)
		if found:
			target_list = found.sub_commands
			active_def = found
		else:
			# 上下文不是本扩展管理的，或者找不到，直接返回
			return []
	
	# 2. 先遍历目标列表进行匹配 (子命令)
	for def in target_list:
		var current_score = 0
		var matched = false
		
		# 去除两端空格，确保 "-node " 可以匹配 "-node"
		var term_stripped = search_term.strip_edges()
		
		if term_stripped.is_empty():
			# 空搜索：显示所有，给个低分
			current_score = 50
			matched = true
		else:
			# 优先匹配 keyword
			var res_key = SpotlightFuzzySearch.fuzzy_match(term_stripped, def.keyword)
			# 其次匹配 title
			var res_title = SpotlightFuzzySearch.fuzzy_match(term_stripped, def.title)
			
			if res_key.matched:
				current_score = res_key.score
				matched = true
				
				# 特殊修正：单字符 "-" 不应高分
				if term_stripped == "-" and def.keyword.begins_with("-"):
					current_score = 10
				# 完全匹配 keyword 给高分 (支持带空格的输入)
				elif term_stripped == def.keyword:
					current_score = 100
					
			elif res_title.matched:
				current_score = res_title.score * 0.8 # Title 匹配权重稍低
				matched = true
		
		if matched:
			var item = _create_item_from_def(def)
			item.score = current_score
			# 子命令通常比动态内容更重要，给个额外加分，确保排在前面
			item.score += 10
			results.append(item)

	# 3. 再调用动态提供者 (Dynamic Provider)
	if active_def and active_def.dynamic_provider.is_valid():
		# 只有当我们在上下文中（即已经进入了该指令），才显示动态内容
		# 如果 context 为空，或者 context.back() 不是当前 active_def，则说明我们只是在搜索这个指令本身
		var in_context = false
		if not context.is_empty() and context.back().get_unique_id() == active_def.id:
			in_context = true
			
		if in_context:
			var dynamic_results = active_def.dynamic_provider.call(text)
			if dynamic_results:
				results.append_array(dynamic_results)
			
	return results

func _create_item_from_def(def: CommandDefinition) -> SpotlightResultItem:
	# 动态创建 ResultItem
	# 如果是 CUSTOM 类型，我们需要一个特殊的 ResultItem 子类来处理 create_custom_preview
	var item
	if def.preview_type == SpotlightResultItem.PreviewType.CUSTOM:
		if def.custom_preview_factory.is_valid():
			item = SimpleCustomResult.new(null)
			item.set_factory(def.custom_preview_factory)
		elif def.custom_preview_script:
			item = SimpleCustomResult.new(def.custom_preview_script)
		else:
			# Fallback
			item = SimpleResultItem.new()
	else:
		item = SimpleResultItem.new()
	
	item.title = def.title
	item.description = def.description
	item.icon = def.icon
	item.type = SpotlightResultItem.ItemType.CATEGORY if def.is_category else SpotlightResultItem.ItemType.LEAF
	item.tags = def.tags
	
	# 绑定唯一 ID
	item.set_meta("unique_id", def.id)
	
	if item is SimpleResultItem:
		item.set_execute_callback(def.callback)
	elif item is SimpleCustomResult:
		item.set_execute_callback(def.callback)

	return item

# 递归查找 CommandDefinition
func _find_command_by_id(list: Array[CommandDefinition], target_id: String) -> CommandDefinition:
	for cmd in list:
		if cmd.id == target_id:
			return cmd
		# 递归查找子命令
		var found = _find_command_by_id(cmd.sub_commands, target_id)
		if found:
			return found
	return null

# --- 核心：解析 Item (用于收藏/历史) ---
func resolve_item(id: String) -> SpotlightResultItem:
	# 尝试在命令定义中查找
	var def = _find_command_by_id(_root_commands, id)
	if def:
		return _create_item_from_def(def)
	return null

# --- 内部类：通用 ResultItem ---
class SimpleResultItem extends SpotlightResultItem:
	var _callback: Callable
	
	func set_execute_callback(cb: Callable):
		_callback = cb
		
	func execute():
		if _callback.is_valid():
			_callback.call()
			
	func get_unique_id() -> String:
		if has_meta("unique_id"):
			return get_meta("unique_id")
		return title

# --- 内部类：支持 Custom Preview 的 ResultItem ---
class SimpleCustomResult extends SpotlightResultItem:
	var _preview_script: Script
	var _factory: Callable
	var _callback: Callable
	
	func _init(script: Script):
		_preview_script = script
	
	func set_factory(cb: Callable):
		_factory = cb
	
	func set_execute_callback(cb: Callable):
		_callback = cb
		
	func execute():
		if _callback.is_valid():
			_callback.call()
		
	func get_preview_type() -> PreviewType:
		return PreviewType.CUSTOM
		
	func create_custom_preview() -> Control:
		if _factory.is_valid():
			return _factory.call()
		elif _preview_script and _preview_script.can_instantiate():
			return _preview_script.new()
		return Label.new()
		
	func get_unique_id() -> String:
		if has_meta("unique_id"):
			return get_meta("unique_id")
		return title
