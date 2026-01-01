@tool
extends SpotlightSimpleExtension

# --- 核心指令重构版 ---

const CreateCommandItemScript = preload("res://addons/spotlight_search/modules/core_commands/create_command_item.gd")

func _init():
	# 1. 注册基础指令
	add_command("-quit", "Quit Editor") \
		.set_description("Close the main editor window.") \
		.set_icon("Close") \
		.set_action(_quit_editor) \
		.set_tags(["Official", "Command"])
		
	add_command("-config", "Open Settings") \
		.set_description("Open Spotlight Search settings panel.") \
		.set_icon("Tools") \
		.set_action(_open_settings) \
		.set_tags(["Official", "Command"])
		
	add_command("-reload", "Reload Project") \
		.set_description("Reloads the current project (restarts the editor).") \
		.set_icon("Reload") \
		.set_action(_reload_project) \
		.set_tags(["Official", "Command"])
		
	add_command("-full", "Toggle Fullscreen") \
		.set_description("Switch between windowed and fullscreen mode.") \
		.set_icon("Window") \
		.set_action(_toggle_fullscreen) \
		.set_tags(["Official", "Command"])

	add_command("-zen", "Toggle Zen Mode") \
		.set_description("Toggle distraction-free mode (hide all docks).") \
		.set_icon("DistractionFree") \
		.set_action(_toggle_zen_mode) \
		.set_tags(["Experimental", "Command"])
		
	var create_panel_script = load("res://addons/spotlight_search/ui/components/create_resource/create_resource_panel.gd")
	var new_cmd = add_command("-new", "Create New Resource") \
		.set_description("Quickly create scripts, scenes, or shaders.") \
		.set_icon("Add") \
		.set_preview_custom(create_panel_script) \
		.set_tags(["Official", "Command"])
	
	# 注册 -new 下的子指令 (作为快捷入口)
	new_cmd.add_command("script", "Create GDScript") \
		.set_description("Create a new .gd script file from template.") \
		.set_icon("GDScript") \
		.set_dynamic_provider(_provide_script_templates) # 动态提供模板
		
	new_cmd.add_command("scene", "Create Scene") \
		.set_description("Create a new .tscn scene file.") \
		.set_icon("PackedScene") \
		.set_action(func(): print("Create Scene called!"))
		
	new_cmd.add_command("shader", "Create Shader") \
		.set_description("Create a new .gdshader file.") \
		.set_icon("ShaderMaterial") \
		.set_action(func(): print("Create Shader called!"))
	pass

func get_id() -> String:
	return "core.commands"

func get_display_name() -> String:
	return "Core Commands"

func get_author() -> String:
	return "Godot Engine"

func get_version() -> String:
	return "1.1.0"

# --- 动态提供者 ---

func _provide_script_templates(query: String) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var script_icon = EditorInterface.get_editor_theme().get_icon("GDScript", "EditorIcons")
	
	var templates = [
		{"name": "Node (Default)", "desc": "Standard empty node script"},
		{"name": "CharacterBody2D", "desc": "Basic 2D movement template"},
		{"name": "Area3D", "desc": "3D Trigger Area"}
	]
	
	for t in templates:
		if query.is_empty() or t.name.to_lower().contains(query.to_lower()):
			var item = SimpleResultItem.new()
			item.title = t.name
			item.description = t.desc
			item.icon = script_icon
			item.score = 100
			item.set_execute_callback(func(): print("Creating script: " + t.name))
			results.append(item)
			
	return results

# --- Actions ---

func _quit_editor():
	print("[Spotlight] Quitting Editor...")
	EditorInterface.get_base_control().get_tree().quit()

func _reload_project():
	EditorInterface.restart_editor(true)

func _open_settings():
	var manager = Engine.get_main_loop().root.get_node_or_null("SpotlightManager")
	if manager and manager.has_signal("request_open_settings"):
		manager.emit_signal("request_open_settings")

func _toggle_fullscreen():
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_zen_mode():
	var current = EditorInterface.is_distraction_free_mode_enabled()
	EditorInterface.set_distraction_free_mode(not current)
