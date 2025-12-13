@tool
extends RefCounted

const ToolkitAPI = preload("res://addons/spotlight_search/api/toolkit_api.gd")
const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
# const ConfigWindowScript = preload("res://addons/spotlight_search/ui/config_window.gd") # Removed to break cyclic dependency

# Action Registry
# Maps Action IDs to Callables
static var _actions: Dictionary = {}
static var _initialized: bool = false

static func register_builtins():
	if _initialized: return
	
	register_action("open_settings", _open_settings)
	register_action("create_file", _create_file)
	register_action("jump_to_node", _jump_to_node)
	register_action("instantiate_scene", _instantiate_scene)
	register_action("open_scene", _open_scene)
	register_action("edit_resource", _edit_resource)
	register_action("select_file", _select_file)
	register_action("reload_project", _reload_project)
	register_action("quit_editor", _quit_editor)
	register_action("toggle_fullscreen", _toggle_fullscreen)
	
	# Scene operations
	register_action("scene_reload", _scene_reload)
	register_action("scene_run", _scene_run)
	register_action("scene_save", _scene_save)
	
	# Color utilities
	register_action("color_pick", _color_pick)
	register_action("color_copy", _color_copy)
	
	_initialized = true

static func register_action(id: String, callable: Callable):
	_actions[id] = callable
	# print("[Spotlight] Registered action: ", id)

static func execute(id: String, args: Array = []):
	# 1. Check built-in registered actions first
	if _actions.has(id):
		# Pass the arguments array as a single argument to the action
		# This ensures actions always receive [arg1, arg2, ...] as a single Array parameter
		return await _actions[id].call(args)
	
	# 2. Check extension-defined actions
	const CommandManager = preload("res://addons/spotlight_search/managers/command_manager.gd")
	if CommandManager.LOADED_ACTIONS.has(id):
		var action_def = CommandManager.LOADED_ACTIONS[id]
		return await _execute_extension_action(action_def, args)
	
	push_warning("[Spotlight] Action '%s' not found." % id)
	return null

static func _execute_extension_action(action_def: Dictionary, args: Array):
	var script_path = action_def.get("script", "")
	var method_name = action_def.get("method", "")
	
	if script_path.is_empty() or method_name.is_empty():
		push_warning("[Spotlight] Extension action missing script or method.")
		return null
	
	if not FileAccess.file_exists(script_path):
		push_warning("[Spotlight] Extension script not found: " + script_path)
		return null
	
	var script = load(script_path)
	if not script:
		push_warning("[Spotlight] Failed to load extension script: " + script_path)
		return null
	
	# Check if method exists and call it
	if script.has_method(method_name):
		return await script.call(method_name, args)
	else:
		push_warning("[Spotlight] Method '%s' not found in script '%s'" % [method_name, script_path])
		return null

static func has_action(id: String) -> bool:
	if _actions.has(id):
		return true
	const CommandManager = preload("res://addons/spotlight_search/managers/command_manager.gd")
	return CommandManager.LOADED_ACTIONS.has(id)

# --- Built-in Action Implementations ---

static func _open_settings(_args: Array = []):
	# Check if window already exists to avoid duplicates
	var base = EditorInterface.get_base_control()
	
	# Try to find by group (more robust than name or children iteration)
	var existing_windows = base.get_tree().get_nodes_in_group("spotlight_config_window")
	if existing_windows.size() > 0:
		var existing = existing_windows[0]
		if is_instance_valid(existing):
			existing.popup_centered()
			# Ensure it's brought to front if it was behind
			existing.grab_focus()
			return
		# If invalid, we continue to create new

	var win_script = load("res://addons/spotlight_search/ui/config_window.gd")
	if win_script:
		var win = win_script.new()
		win.name = "SpotlightConfigWindow" # Set name for finding later
		base.add_child(win)
		win.popup_centered()

static func _create_file(args: Array):
	if args.is_empty(): return
	var path = args[0]
	print("[Spotlight] Creating file: ", path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var content = ""
		if path.to_lower().ends_with(".gdshader"):
			content = "shader_type spatial;\n\nvoid vertex() {\n\t\n}\n\nvoid fragment() {\n\t\n}\n"
		else:
			content = "extends Node\n\nfunc _ready():\n\tpass\n"
		
		file.store_string(content)
		file.close()
		EditorInterface.get_resource_filesystem().scan()
		
		# Wait slightly for scan
		await EditorInterface.get_base_control().get_tree().create_timer(0.1).timeout
		
		# Try to open the file based on its type
		if ResourceLoader.exists(path):
			EditorInterface.edit_resource(load(path))
		else:
			EditorInterface.select_file(path)
			print("[Spotlight] Created non-resource file: ", path)

static func _jump_to_node(args: Array):
	if args.is_empty(): return
	var path = args[0]
	var root = EditorInterface.get_edited_scene_root()
	if root:
		var node = root.get_node_or_null(path)
		if node:
			EditorInterface.get_selection().clear()
			EditorInterface.get_selection().add_node(node)
			if node is Node3D or node is CollisionObject3D:
				EditorInterface.set_main_screen_editor("3D")
			elif node is Node2D or node is Control:
				EditorInterface.set_main_screen_editor("2D")

static func _instantiate_scene(args: Array):
	if args.is_empty(): return
	var path = args[0]
	if not FileAccess.file_exists(path):
		push_warning("[Spotlight] File not found: " + path)
		return
		
	var packed = load(path)
	if not packed: return
	
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		print("Spotlight Search: No active scene root.")
		return
		
	var node = packed.instantiate()
	var sel = EditorInterface.get_selection().get_selected_nodes()
	var p = sel[0] if sel else root
	
	p.add_child(node)
	node.owner = root
	
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	
	if node is Node3D or node is CollisionObject3D:
		EditorInterface.set_main_screen_editor("3D")
	else:
		EditorInterface.set_main_screen_editor("2D")
	
	print("Spotlight Search: Added '%s' to '%s'" % [node.name, p.name])

static func _open_scene(args: Array):
	if args.is_empty(): return
	var path = args[0]
	if not FileAccess.file_exists(path):
		push_warning("[Spotlight] Scene not found: " + path)
		return
	EditorInterface.open_scene_from_path(path)
	# Wait for editor to switch
	await EditorInterface.get_base_control().get_tree().process_frame
	
	var root = EditorInterface.get_edited_scene_root()
	if root and root is Node3D: 
		EditorInterface.set_main_screen_editor("3D")
	else: 
		EditorInterface.set_main_screen_editor("2D")

static func _edit_resource(args: Array):
	if args.is_empty(): return
	var path = args[0]
	if not FileAccess.file_exists(path):
		push_warning("[Spotlight] Resource not found: " + path)
		return
		
	# Try to load as resource first
	if ResourceLoader.exists(path):
		var res = load(path)
		if res: 
			EditorInterface.edit_resource(res)
			return
	
	var text_extensions = ["json", "md", "txt", "cfg", "ini", "csv", "xml", "html", "css", "toml", "yaml", "yml"]
	var ext = path.get_extension().to_lower()
	
	if ext in text_extensions:
		# Switch to Script editor first, then select the file
		EditorInterface.set_main_screen_editor("Script")
		EditorInterface.select_file(path)
		
		print("[Spotlight] Text file selected. Press Enter or double-click to open: ", path)
		return
			
	# Fallback for truly non-resource files
	EditorInterface.select_file(path)
	print("[Spotlight] Selected file (non-resource): ", path)

static func _select_file(args: Array):
	if args.is_empty(): return
	var path = args[0]
	if not FileAccess.file_exists(path):

		if not DirAccess.dir_exists_absolute(path):
			push_warning("[Spotlight] Path not found: " + path)
			return
	EditorInterface.select_file(path)

static func _reload_project(_args: Array):
	print("[Spotlight] Reloading project...")
	EditorInterface.restart_editor(true)

static func _quit_editor(_args: Array):
	print("[Spotlight] Quitting editor...")
	EditorInterface.get_base_control().get_tree().quit()

static func _toggle_fullscreen(_args: Array):
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# --- Scene Operations ---

static func _scene_reload(_args: Array):
	var current = EditorInterface.get_edited_scene_root()
	if not current:
		ToolkitAPI.show_toast("No scene open", "warning")
		return
	
	var path = current.scene_file_path
	if path.is_empty():
		ToolkitAPI.show_toast("Scene not saved yet", "warning")
		return
	
	EditorInterface.reload_scene_from_path(path)
	ToolkitAPI.show_toast("Reloaded: " + path.get_file(), "success")

static func _scene_run(_args: Array):
	var current = EditorInterface.get_edited_scene_root()
	if not current:
		ToolkitAPI.show_toast("No scene open", "warning")
		return
	
	EditorInterface.play_current_scene()
	ToolkitAPI.show_toast("Running scene...", "success")

static func _scene_save(_args: Array):
	var current = EditorInterface.get_edited_scene_root()
	if not current:
		ToolkitAPI.show_toast("No scene open", "warning")
		return
	
	EditorInterface.save_scene()
	ToolkitAPI.show_toast("Scene saved", "success")

# --- Color Utilities ---

static func _color_pick(_args: Array):
	# Create a proper Window for color picker (PopupPanel closes immediately)
	var window = Window.new()
	window.title = "Color Picker"
	window.size = Vector2i(350, 450)
	window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	window.unresizable = false
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	window.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var picker = ColorPicker.new()
	picker.color = Color.WHITE
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(picker)
	
	# Buttons
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	
	var btn_copy = Button.new()
	btn_copy.text = "Copy Color()"
	btn_copy.pressed.connect(func():
		var c = picker.color
		var gdscript_format = "Color(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]
		DisplayServer.clipboard_set(gdscript_format)
		ToolkitAPI.show_toast("Copied: " + gdscript_format, "success")
	)
	hbox.add_child(btn_copy)
	
	var btn_hex = Button.new()
	btn_hex.text = "Copy #HEX"
	btn_hex.pressed.connect(func():
		var hex = "#" + picker.color.to_html(false).to_upper()
		DisplayServer.clipboard_set(hex)
		ToolkitAPI.show_toast("Copied: " + hex, "success")
	)
	hbox.add_child(btn_hex)
	
	var btn_close = Button.new()
	btn_close.text = "Close"
	btn_close.pressed.connect(window.queue_free)
	hbox.add_child(btn_close)
	
	EditorInterface.get_base_control().add_child(window)
	
	# Center manually and show
	var screen_size = DisplayServer.screen_get_size()
	window.position = Vector2i((screen_size.x - window.size.x) / 2, (screen_size.y - window.size.y) / 2)
	window.show()
	
	# Clean up when closed
	window.close_requested.connect(window.queue_free)

static func _color_copy(args: Array):
	if args.is_empty():
		ToolkitAPI.show_toast("No color to copy", "warning")
		return
	
	var color_str = str(args[0])
	DisplayServer.clipboard_set(color_str)
	ToolkitAPI.show_toast("Copied: " + color_str, "success")
