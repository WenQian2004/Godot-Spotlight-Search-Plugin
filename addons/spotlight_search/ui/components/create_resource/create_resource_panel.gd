@tool
extends MarginContainer

# UI Components
var name_input: LineEdit
var path_input: LineEdit
var type_option: OptionButton
var create_btn: Button
var error_label: Label

# Constants
const TYPES = [
	{"name": "GDScript", "ext": "gd", "icon": "GDScript"},
	{"name": "Scene (Node)", "ext": "tscn", "icon": "PackedScene"},
	{"name": "Shader", "ext": "gdshader", "icon": "Shader"},
	{"name": "Text File", "ext": "txt", "icon": "TextFile"},
	{"name": "Folder", "ext": "", "icon": "Folder"}
]

func _ready():
	_setup_ui()
	_update_defaults()

func _setup_ui():
	# Style
	add_theme_constant_override("margin_left", 20)
	add_theme_constant_override("margin_right", 20)
	add_theme_constant_override("margin_top", 20)
	add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)
	
	# Header
	var header = Label.new()
	header.text = "Create New Resource"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
	vbox.add_child(header)
	
	# Grid Form
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	
	# Row 1: Type
	var type_lbl = Label.new()
	type_lbl.text = "Type:"
	grid.add_child(type_lbl)
	
	type_option = OptionButton.new()
	for i in range(TYPES.size()):
		var t = TYPES[i]
		var icon = get_theme_icon(t.icon, "EditorIcons")
		type_option.add_icon_item(icon, t.name, i)
	type_option.item_selected.connect(_on_type_changed)
	grid.add_child(type_option)
	
	# Row 2: Name
	var name_lbl = Label.new()
	name_lbl.text = "Name:"
	grid.add_child(name_lbl)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "e.g. MyScript"
	name_input.custom_minimum_size.x = 250
	name_input.text_changed.connect(_on_input_changed)
	name_input.text_submitted.connect(func(_t): _on_create_pressed())
	grid.add_child(name_input)
	
	# Row 3: Path
	var path_lbl = Label.new()
	path_lbl.text = "Location:"
	grid.add_child(path_lbl)
	
	var path_hbox = HBoxContainer.new()
	path_input = LineEdit.new()
	path_input.text = "res://"
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_input.tooltip_text = "Target Directory"
	path_hbox.add_child(path_input)
	
	var browse_btn = Button.new()
	browse_btn.icon = get_theme_icon("Folder", "EditorIcons")
	browse_btn.tooltip_text = "Select Directory"
	browse_btn.pressed.connect(_on_browse_pressed)
	path_hbox.add_child(browse_btn)
	grid.add_child(path_hbox)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Error Label
	error_label = Label.new()
	error_label.add_theme_color_override("font_color", get_theme_color("error_color", "Editor"))
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.visible = false
	vbox.add_child(error_label)
	
	# Create Button
	create_btn = Button.new()
	create_btn.text = "Create Resource"
	create_btn.custom_minimum_size.y = 40
	create_btn.pressed.connect(_on_create_pressed)
	vbox.add_child(create_btn)

func _update_defaults():
	# Do not auto focus name input, wait for user to Tab into it
	# name_input.grab_focus()
	_on_type_changed(0) # trigger extension update

func _on_type_changed(idx):
	var t = TYPES[idx]
	# Update placeholder or extension hint if needed
	pass

func _on_input_changed(_text):
	error_label.visible = false

func _on_browse_pressed():
	var dlg = EditorFileDialog.new()
	dlg.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dlg.current_dir = path_input.text
	dlg.dir_selected.connect(func(path): path_input.text = path)
	add_child(dlg)
	dlg.popup_centered_ratio(0.5)

func _on_create_pressed():
	var idx = type_option.selected
	var type_data = TYPES[idx]
	var base_name = name_input.text.strip_edges()
	var dir_path = path_input.text.strip_edges()
	
	if base_name.is_empty():
		_show_error("Please enter a file name.")
		return
		
	if not dir_path.ends_with("/"):
		dir_path += "/"
		
	# Ensure directory exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(dir_path):
		var err = dir.make_dir_recursive(dir_path)
		if err != OK:
			_show_error("Failed to create directory: " + dir_path)
			return
	
	# Handle Folder creation separately
	if type_data.ext == "": 
		var full_path = dir_path + base_name
		if dir.dir_exists(full_path):
			_show_error("Folder already exists.")
			return
		var err = dir.make_dir(full_path)
		if err == OK:
			_success(full_path, true)
		else:
			_show_error("Failed to create folder.")
		return
	
	# Handle File creation
	var ext = type_data.ext
	var full_path = dir_path + base_name
	if not full_path.ends_with("." + ext):
		full_path += "." + ext
		
	if FileAccess.file_exists(full_path):
		_show_error("File already exists: " + full_path.get_file())
		return
		
	# Create Content
	var err = OK
	match type_data.name:
		"GDScript":
			var file = FileAccess.open(full_path, FileAccess.WRITE)
			if file:
				file.store_string("extends Node\n\nfunc _ready():\n\tpass\n")
				file.close()
			else: err = FileAccess.get_open_error()
			
		"Scene (Node)":
			var node = Node.new()
			node.name = base_name
			var packed = PackedScene.new()
			packed.pack(node)
			err = ResourceSaver.save(packed, full_path)
			node.free()
			
		"Shader":
			var code = "shader_type canvas_item;\n\nvoid fragment() {\n\t// Place fragment code here.\n}\n"
			var file = FileAccess.open(full_path, FileAccess.WRITE)
			if file:
				file.store_string(code)
				file.close()
			else: err = FileAccess.get_open_error()
			
		"Text File":
			var file = FileAccess.open(full_path, FileAccess.WRITE)
			if file:
				file.store_string("") # Empty
				file.close()
			else: err = FileAccess.get_open_error()
			
	if err == OK:
		_success(full_path)
	else:
		_show_error("Error creating file: " + str(err))

func _show_error(msg):
	error_label.text = msg
	error_label.visible = true
	
	# Shake effect
	var tween = create_tween()
	tween.tween_property(start_shake_node(create_btn), "position:x", 5, 0.05).as_relative()
	tween.tween_property(create_btn, "position:x", -10, 0.05).as_relative()
	tween.tween_property(create_btn, "position:x", 5, 0.05).as_relative()

func start_shake_node(node):
	return node

func _success(path, is_dir=false):
	# Refresh FileSystem
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(0.1).timeout # wait for scan
	
	var fs = EditorInterface.get_file_system_dock()
	if fs:
		fs.navigate_to_path(path)
		
	if not is_dir:
		if path.get_extension() == "tscn":
			EditorInterface.open_scene_from_path(path)
		elif path.get_extension() == "gd":
			var res = load(path)
			if res: EditorInterface.edit_script(res)
		else:
			OS.shell_open(ProjectSettings.globalize_path(path))
			
	# Close Spotlight?
	# We can't easily close spotlight from here unless we emit signal or call manager
	# But creating a file usually steals focus to the Editor, which will auto-close Spotlight via _on_popup_hide() logic?
	# Spotlight monitors focus loss?
	# Actually main_window.gd has _on_popup_hide, but if we just change focus, it might not hide PopupPanel automatically if it's modal?
	# PopupPanel hides on outside click or loss of focus.
	
	# Let's try to notify user visually
	create_btn.text = "Created!"
	create_btn.disabled = true
	var t = get_tree().create_timer(1.0)
	await t.timeout
	create_btn.text = "Create Resource"
	create_btn.disabled = false
