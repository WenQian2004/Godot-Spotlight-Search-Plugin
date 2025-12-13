@tool
extends EditorPlugin

var window_scene = preload("res://addons/spotlight_search/ui/spotlight_window.tscn")
var tracker_script = preload("res://addons/spotlight_search/editor/spotlight_tracker.gd")
const CommandManager = preload("res://addons/spotlight_search/managers/command_manager.gd")
const ConfigManager = preload("res://addons/spotlight_search/managers/config_manager.gd")
const ConfigWindow = preload("res://addons/spotlight_search/ui/config_window.gd")
const ActionRegistry = preload("res://addons/spotlight_search/services/action_registry.gd")
const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")

var window_instance
var tracker_instance
var settings_btn: Button
var _extensions: Array = []

func _enter_tree():
	_ensure_extension_folder()
	_load_extensions()
	
	ConfigManager.register_settings()
	CommandManager.load_all_commands()
	window_instance = window_scene.instantiate()
	window_instance.name = "SpotlightWindow"
	EditorInterface.get_base_control().add_child(window_instance)
	window_instance.hide()
	
	tracker_instance = tracker_script.new()
	add_inspector_plugin(tracker_instance)
	
	settings_btn = Button.new()
	settings_btn.text = TranslationService.get_string("ui_toolbar_btn")
	settings_btn.tooltip_text = TranslationService.get_string("ui_toolbar_tooltip")
	settings_btn.flat = true
	settings_btn.pressed.connect(_on_settings_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, settings_btn)
	_update_icon.call_deferred()

func _ensure_extension_folder():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("toolkit_extensions"):
		dir.make_dir("toolkit_extensions")
		print("[Spotlight] Created 'toolkit_extensions' directory.")
	

func _load_extensions():
	_extensions.clear()
	var path = "res://toolkit_extensions/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gd"):
				var script_path = path + file_name
				var script = load(script_path)
				if script:
					var instance = script.new()
					_extensions.append(instance)
					print("[Spotlight] Loaded extension: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func _update_icon():
	if settings_btn:
		settings_btn.icon = EditorInterface.get_editor_theme().get_icon("Search", "EditorIcons")

func _exit_tree():
	if window_instance: window_instance.queue_free()
	if tracker_instance: remove_inspector_plugin(tracker_instance)
	if settings_btn:
		remove_control_from_container(CONTAINER_TOOLBAR, settings_btn)
		settings_btn.queue_free()

func _on_settings_pressed():
	ActionRegistry.execute("open_settings")

func _input(event):
	if event is InputEventKey:
		if ConfigManager.is_shortcut(event):
			if window_instance.visible:
				window_instance.hide()
			else:
				window_instance.popup_custom()
			get_viewport().set_input_as_handled()
