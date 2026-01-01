@tool
extends "res://addons/spotlight_search/core/spotlight_simple_extension.gd"

func _init():
	# 注册 -tabs 指令
	var tabs = add_command("-tabs", "Switch Open Tabs") \
		.set_description("Switch between open script and scene tabs.") \
		.set_icon("GuiTab") \
		.set_dynamic_provider(_provide_open_tabs) \
		.set_tags(["Command", "ThirdParty"])

func get_id() -> String:
	return "wenqian.open_editors"

func get_display_name() -> String:
	return "Open Editors Switcher"
	
func get_author() -> String:
	return "WenQian"

func get_version() -> String:
	return "1.0.0"

# --- 动态提供者 ---
func _provide_open_tabs(query: String) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var script_editor = EditorInterface.get_script_editor()
	var open_scripts = script_editor.get_open_scripts()
	var open_scenes = EditorInterface.get_open_scenes()
	
	var script_icon = EditorInterface.get_editor_theme().get_icon("Script", "EditorIcons")
	var scene_icon = EditorInterface.get_editor_theme().get_icon("PackedScene", "EditorIcons")
	
	# 1. Scripts
	for script in open_scripts:
		var path = script.resource_path
		var name = path.get_file()
		
		# 简单的包含匹配
		if query.is_empty() or name.to_lower().contains(query.to_lower()):
			var item = SimpleResultItem.new()
			item.title = name
			item.description = path
			item.icon = script_icon
			item.score = 100
			
			item.set_execute_callback(func():
				EditorInterface.edit_resource(script)
			)
			results.append(item)
			
	# 2. Scenes
	for path in open_scenes:
		var name = path.get_file()
		
		if query.is_empty() or name.to_lower().contains(query.to_lower()):
			var item = SimpleResultItem.new()
			item.title = name
			item.description = path
			item.icon = scene_icon
			item.score = 100
			
			item.set_execute_callback(func():
				EditorInterface.open_scene_from_path(path)
			)
			results.append(item)
			
	return results
