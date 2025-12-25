@tool
extends SpotlightExtension

const SCORE_BASE = 100

func _init():
	# No dynamic loading needed thanks to global class_names
	pass

# 核心系统指令配置
# 格式: "-command": { "desc": "...", "icon": "...", "action": Callable }
# 注意：这里只处理 Actions，不处理 Filters (由 FileExtension 处理)
var SYSTEM_COMMANDS = {
	"-new": { 
		"desc": "Create new resources (script, scene, etc.)", 
		"icon": "Add", 
		"is_category": true, # 特殊标记，这是一个 Category
		"action": Callable() 
	},
	"-quit": { 
		"desc": "Quit Godot Editor", 
		"icon": "Close", 
		"is_category": false,
		"action": Callable(self, "_quit_editor")
	},
	"-config": { 
		"desc": "Action: Open Settings", 
		"icon": "Tools", 
		"is_category": false,
		"action": Callable(self, "_open_settings")
	},
	"-reload": { 
		"desc": "Action: Reload Project", 
		"icon": "Reload", 
		"is_category": false,
		"action": Callable(self, "_reload_project")
	},
	"-full": { 
		"desc": "Action: Toggle Fullscreen", 
		"icon": "Window", 
		"is_category": false,
		"action": Callable(self, "_toggle_fullscreen")
	},
	"-node": {
		"desc": "Browse Engine Nodes",
		"icon": "Node",
		"is_category": true, # 标记为目录，选中后进入 cmd.node 上下文
		"action": Callable()
	},
	"-track": {
		"desc": "Track Scene Nodes",
		"icon": "Search",
		"is_category": true, # 进入 cmd.track 上下文
		"action": Callable()
	}
}

# 子命令数据定义
var create_new_subcommands = [
	["script", "-script", "Create a new GDScript file", "GDScript", func(): print("Create Script called!"), true],
	["scene", "-scene", "Create a new .tscn scene", "PackedScene", func(): print("Create Scene called!"), false],
	["shader", "-shader", "Create a new shader resource", "ShaderMaterial", func(): print("Create Shader called!"), false],
]

func get_id() -> String: 
	return "core.commands"

func get_display_name() -> String: 
	return "Core Commands"

func get_author() -> String:
	return "Godot Engine"

func get_version() -> String:
	return "1.1.0"

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = text.to_lower()

	# ---------------------------------------------------------
	# 1. 顶层命令 (当没有上下文时)
	# ---------------------------------------------------------
	if context.is_empty():
		var matched_cmds = []
		
		for cmd_key in SYSTEM_COMMANDS:
			var score = 0
			if search_term.is_empty():
				# 空搜索：显示所有，但分数较低
				score = SCORE_BASE
			else:
				# 尝试模糊匹配命令关键字 (e.g. "-new") 或者 描述
				var match_res_key = SpotlightFuzzySearch.fuzzy_match(search_term, cmd_key)
				var match_res_desc = SpotlightFuzzySearch.fuzzy_match(search_term, SYSTEM_COMMANDS[cmd_key].desc)
				
				# 取最高分
				var best_res = match_res_key
				if match_res_desc.score > match_res_key.score:
					best_res = match_res_desc
					
				if not best_res.matched:
					continue
				score = best_res.score
			
			matched_cmds.append({
				"key": cmd_key,
				"score": score
			})
		
		# 排序
		matched_cmds.sort_custom(func(a, b): return a.score > b.score)
		
		for m in matched_cmds:
			var cmd_key = m.key
			var info = SYSTEM_COMMANDS[cmd_key]
			var icon = EditorInterface.get_editor_theme().get_icon(info.icon, "EditorIcons")
			
			var cmd
			
			# 特殊处理：使用自定义 Item 的命令
			if cmd_key == "-new" and CreateCommandResult:
				cmd = CreateCommandResult.new()
			else:
				cmd = CommandResult.new(
					"cmd." + cmd_key.trim_prefix("-"),
					cmd_key, 
					info.desc, 
					icon, 
					info.action, 
					info.get("is_category", false)
				)
				
			cmd.tags = ["Official", "Command"]
			cmd.score = m.score # 赋值分数
			results.append(cmd)

	# ---------------------------------------------------------
	# 2. 嵌套命令 (当在某个上下文中)
	# ---------------------------------------------------------
	elif not context.is_empty():
		var last_context_item = context.back()
		
		if last_context_item is CommandResult:
			if last_context_item.command_id == "cmd.new":
				for cmd_data in create_new_subcommands:
					var title = cmd_data[1]
					var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, title)
					if not search_term.is_empty() and not match_res.matched:
						continue
						
					var icon = EditorInterface.get_editor_theme().get_icon(cmd_data[3], "EditorIcons")
					var sub_cmd = CommandResult.new(
						"cmd.new." + cmd_data[0], 
						title, 
						cmd_data[2], 
						icon, 
						cmd_data[4], 
						cmd_data[5]
					)
					sub_cmd.tags = ["Official", "Nested"]
					sub_cmd.score = match_res.score
					results.append(sub_cmd)
			
			elif last_context_item.command_id == "cmd.new.script":
				# 示例：创建具体脚本类型的子命令
				# 这里展示如何根据输入过滤预定义的模板列表
				var script_icon = EditorInterface.get_editor_theme().get_icon("GDScript", "EditorIcons")
				
				var items = [
					CommandResult.new("cmd.new.script.node", "Node (Default)", "Standard empty node script", script_icon, func(): print("Creating default node script..."), false),
					CommandResult.new("cmd.new.script.char2d", "CharacterBody2D", "Basic 2D movement template", script_icon, func(): print("Creating CharBody2D script..."), false)
				]
				
				for it in items:
					var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, it.title)
					if search_term.is_empty() or match_res.matched:
						it.tags = ["Official", "Template"] # 为模板项添加标签
						it.score = match_res.score
						results.append(it)

	return results

# 恢复收藏的指令项
func resolve_item(id: String) -> SpotlightResultItem:
	if id.begins_with("cmd."):
		var key_suffix = id.substr(4)
		# 对于嵌套指令，只简单处理顶级
		var cmd_key = "-" + key_suffix
		
		# 尝试 System Commands
		if cmd_key in SYSTEM_COMMANDS:
			var info = SYSTEM_COMMANDS[cmd_key]
			var icon = EditorInterface.get_editor_theme().get_icon(info.icon, "EditorIcons")
			var item
			
			if cmd_key == "-new" and CreateCommandResult:
				item = CreateCommandResult.new()
			else:
				item = CommandResult.new(
					id,
					cmd_key, 
					info.desc, 
					icon, 
					info.action, 
					info.get("is_category", false)
				)
			item.tags = ["Official", "Command"]
			return item
			
	return null

# --- New Handlers (Actions) ---

func _quit_editor():
	print("[Spotlight] Quitting Editor...")
	EditorInterface.get_base_control().get_tree().quit()

func _reload_project():
	EditorInterface.restart_editor(true)

func _open_settings():
	# 动态加载 SettingsPanel
	var base_path = get_script().resource_path.get_base_dir().get_base_dir().get_base_dir()
	var SettingsPanel = load(base_path + "/ui/settings_panel/settings_panel.gd")
	var settings_win = SettingsPanel.new()
	EditorInterface.get_base_control().add_child(settings_win)
	settings_win.popup_centered()

func _toggle_fullscreen():
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# --- 辅助方法 ---

func _try_load_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
