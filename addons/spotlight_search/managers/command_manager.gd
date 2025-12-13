@tool
extends RefCounted

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
const ConfigManager = preload("res://addons/spotlight_search/managers/config_manager.gd")
const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")
const ToolkitAPI = preload("res://addons/spotlight_search/api/toolkit_api.gd")

# CommandManager (Refactored CommandRegistry)
# Handles loading and management of all commands from various sources.

static func get_builtin_commands() -> Dictionary:
	return {
		"-new": {
			"desc": TranslationService.get_string("cmd_new_res"),
			"type": "container",
			"icon": "Add",
			"children": {
				"-script": {
					"desc": TranslationService.get_string("cmd_new_script"),
					"type": "create_file",
					"extension": "gd",
					"icon": "Script",
					"handler": "create_file"
				},
				"-shader": {
					"desc": TranslationService.get_string("cmd_new_shader"),
					"type": "create_file",
					"extension": "gdshader",
					"icon": "Shader",
					"handler": "create_file"
				}
			}
		},
		"-scene": {
			"desc": TranslationService.get_string("cmd_scene_ops"),
			"type": "container",
			"icon": "PackedScene",
			"children": {
				"-reload": { "desc": TranslationService.get_string("cmd_reload_scene"), "type": "action", "handler": "scene_reload", "icon": "Reload" },
				"-run": { "desc": TranslationService.get_string("cmd_run_scene"), "type": "action", "handler": "scene_run", "icon": "PlayScene" },
				"-save": { "desc": TranslationService.get_string("cmd_save_scene"), "type": "action", "handler": "scene_save", "icon": "Save" }
			}
		},
		"-color": {
			"desc": TranslationService.get_string("cmd_color_utils"),
			"type": "custom",
			"handler": "color_picker",
			"icon": "ColorPick"
		},
		"-track": {
			"desc": TranslationService.get_string("cmd_track_nodes"),
			"type": "filter",
			"handler": "search_nodes"
		},
		"-node": {
			"desc": TranslationService.get_string("cmd_browse_nodes"),
			"type": "custom", 
			"handler": "list_engine_nodes",
			"icon": "Node"
		},
		"-class": {
			"desc": TranslationService.get_string("cmd_browse_class"),
			"type": "custom", 
			"handler": "list_class_members",
			"icon": "Object"
		},
		"-gd": { "desc": TranslationService.get_string("cmd_filter_gd"), "type": "filter", "target_type": SearchData.Type.SCRIPT },
		"-sc": { "desc": TranslationService.get_string("cmd_filter_scene"), "type": "filter", "target_type": SearchData.Type.SCENE },
		"-img": { "desc": TranslationService.get_string("cmd_filter_img"), "type": "filter", "target_type": SearchData.Type.IMAGE },
		"-res": { "desc": TranslationService.get_string("cmd_filter_res"), "type": "filter", "target_type": SearchData.Type.RESOURCE },
		"-config": {
			"desc": TranslationService.get_string("cmd_config"),
			"type": "container",
			"children": {
				"-plugin_setting": {
					"desc": TranslationService.get_string("cmd_open_settings"),
					"type": "action",
					"handler": "open_settings"
				}
			}
		},
		"-reload": { "desc": TranslationService.get_string("cmd_reload_project"), "type": "action", "handler": "reload_project", "icon": "Reload" },
		"-quit": { "desc": TranslationService.get_string("cmd_quit_editor"), "type": "action", "handler": "quit_editor", "icon": "Exit" },
		"-fs": { "desc": TranslationService.get_string("cmd_toggle_fullscreen"), "type": "action", "handler": "toggle_fullscreen", "icon": "Window" }
	}

static var COMMANDS = {}
static var LOADED_CONFIGS: Array[Dictionary] = []
static var LOADED_PATHS: Array[String] = []
static var LOADED_ACTIONS: Dictionary = {}  # action_id -> { script, method }
static var _initialized = false

static func load_all_commands(force_reload: bool = false):
	if _initialized and not force_reload: return
	_initialized = true
	
	LOADED_CONFIGS.clear()
	LOADED_PATHS.clear()
	LOADED_ACTIONS.clear()
	COMMANDS = get_builtin_commands()
	
	# Load user-imported configs (from Settings)
	var externals = ConfigManager.get_external_configs()
	if externals is Dictionary:
		for path in externals:
			var cfg = externals[path]
			if cfg.get("enabled", true):
				_load_config_file(path)

static func _load_config_file(path: String, is_system: bool = false):
	if path in LOADED_PATHS: return

	if not FileAccess.file_exists(path):
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		var err_msg = "JSON Parse Error in %s: line %s" % [path, json.get_error_line()]
		push_warning("[Spotlight] " + err_msg)
		ToolkitAPI.show_toast(err_msg, "error")
		LOADED_CONFIGS.append({"path": path, "status": "error", "error_msg": err_msg, "is_system": is_system})
		return

	var data = json.data
	var meta = {}
	var commands = []
	var actions = {}
	
	if data is Dictionary and data.has("commands") and data["commands"] is Array:
		meta = data.get("meta", {})
		commands = data["commands"]
		# New: Parse actions section
		if data.has("actions") and data["actions"] is Dictionary:
			actions = data["actions"]
	elif data is Array:
		meta = {"name": path.get_file(), "version": "0.0.0"}
		commands = data
	else:
		return # Invalid format
		
	LOADED_CONFIGS.append({
		"path": path,
		"status": "ok",
		"meta": meta,
		"command_count": commands.size(),
		"action_count": actions.size(),
		"is_system": is_system
	})
	LOADED_PATHS.append(path)
	
	# Register actions from this extension
	for action_id in actions:
		var action_def = actions[action_id]
		LOADED_ACTIONS[action_id] = action_def
	
	for item in commands:
		if item is Dictionary:
			_register_json_item(item, COMMANDS)

static func _register_json_item(item: Dictionary, parent_dict: Dictionary):
	var keyword = item.get("keyword", "")
	if keyword.is_empty(): return
	
	if not keyword.begins_with("-"):
		keyword = "-" + keyword
		
	var entry = {}
	entry["desc"] = item.get("description", "User Command")
	entry["name"] = item.get("name", entry["desc"])
	entry["icon"] = item.get("icon", "Script")
	
	# Store argument definitions if present
	if item.has("args_def"):
		entry["args_def"] = item["args_def"]
	
	# Pre-defined arguments
	if item.has("args"):
		entry["args"] = item["args"]
	
	# Handle Children (Container)
	var children_list = []
	if item.has("commands") and item["commands"] is Array:
		children_list = item["commands"]
	elif item.has("children") and item["children"] is Array:
		children_list = item["children"]
		
	if not children_list.is_empty():
		entry["type"] = "container"
		entry["children"] = {}
		for child in children_list:
			if child is Dictionary:
				_register_json_item(child, entry["children"])
	
	# Handle Filter
	elif item.get("type") == "filter":
		entry["type"] = "filter"
		entry["target_type"] = item.get("target_type", -1)
		entry["handler"] = item.get("handler", "")
		
	# Handle Action
	else:
		var action_id = item.get("action_id", "")
		if not action_id.is_empty():
			entry["type"] = "action"
			entry["handler"] = action_id
		else:
			entry["type"] = "action"
			entry["handler"] = "unknown"
			
	parent_dict[keyword] = entry
