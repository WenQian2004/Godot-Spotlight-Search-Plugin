@tool
extends Window

## Spotlight Settings Panel

# Variables
var listening_for_input = false
var current_shortcut = {}


# UI Nodes
var allowed_exts_edit: TextEdit
var excludes_edit: TextEdit
var max_results_spin: SpinBox
var max_preview_spin: SpinBox
var extensions_container: VBoxContainer
var shortcut_btn: Button
var shortcut_label: Label


func _ready():
	title = "Spotlight Settings"
	size = Vector2i(600, 550)
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	close_requested.connect(queue_free)
	
	# Register Settings
	SpotlightConfig.register_settings()

	
	_build_ui()
	_load_values()

func _build_ui():
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = get_theme_color("base_color", "Editor")
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(main_vbox)
	
	# Header
	var header = Label.new()
	header.text = "Spotlight Settings"
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(header)
	
	# Separator
	main_vbox.add_child(_create_separator())
	
	# Scroll Container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	scroll.add_child(content)
	
	# === Search Settings ===
	_add_section_header(content, "Search Settings")
	
	# Shortcut Settings
	var h_shortcut = HBoxContainer.new()
	content.add_child(h_shortcut)
	
	var lbl_shortcut = Label.new()
	lbl_shortcut.text = "Activation Shortcut"
	lbl_shortcut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_shortcut.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	h_shortcut.add_child(lbl_shortcut)
	
	shortcut_btn = Button.new()
	shortcut_btn.text = "Click to Set"
	shortcut_btn.toggle_mode = true
	shortcut_btn.toggled.connect(_on_shortcut_btn_toggled)
	h_shortcut.add_child(shortcut_btn)
	
	shortcut_label = Label.new()
	shortcut_label.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
	h_shortcut.add_child(shortcut_label)

	var h_results = HBoxContainer.new()
	content.add_child(h_results)
	var lbl_results = Label.new()
	lbl_results.text = "Max Results"
	lbl_results.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	lbl_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_results.add_child(lbl_results)
	
	max_results_spin = SpinBox.new()
	max_results_spin.min_value = 10
	max_results_spin.max_value = 9999
	h_results.add_child(max_results_spin)
	
	# Max Preview Length
	var h_preview = HBoxContainer.new()
	content.add_child(h_preview)
	var lbl_preview = Label.new()
	lbl_preview.text = "Preview Length (chars)"
	lbl_preview.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	lbl_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_preview.add_child(lbl_preview)
	
	max_preview_spin = SpinBox.new()
	max_preview_spin.min_value = 100
	max_preview_spin.max_value = 5000
	max_preview_spin.step = 100
	h_preview.add_child(max_preview_spin)
	
	# === Exclude Directories ===
	_add_section_header(content, "Exclude Directories")
	
	var lbl_exclude_hint = Label.new()
	lbl_exclude_hint.text = "One path fragment per line. Directories containing these fragments will be skipped."
	lbl_exclude_hint.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
	lbl_exclude_hint.add_theme_font_size_override("font_size", 12)
	content.add_child(lbl_exclude_hint)
	
	excludes_edit = TextEdit.new()
	excludes_edit.custom_minimum_size = Vector2(0, 120)
	excludes_edit.placeholder_text = ".git/\n.import/\n.godot/\naddons/"
	var edit_style = StyleBoxFlat.new()
	edit_style.bg_color = get_theme_color("dark_color_2", "Editor")
	edit_style.corner_radius_top_left = 6
	edit_style.corner_radius_top_right = 6
	edit_style.corner_radius_bottom_left = 6
	edit_style.corner_radius_bottom_right = 6
	excludes_edit.add_theme_stylebox_override("normal", edit_style)
	excludes_edit.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	content.add_child(excludes_edit)
	
	# === Allowed Extensions ===
	_add_section_header(content, "Allowed File Types")
	
	var lbl_exts_hint = Label.new()
	lbl_exts_hint.text = "Only search files with these extensions (no dot, one per line)"
	lbl_exts_hint.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
	lbl_exts_hint.add_theme_font_size_override("font_size", 12)
	content.add_child(lbl_exts_hint)
	
	allowed_exts_edit = TextEdit.new()
	allowed_exts_edit.custom_minimum_size = Vector2(0, 100)
	allowed_exts_edit.placeholder_text = "gd\ntscn\npng"
	var exts_style = StyleBoxFlat.new()
	exts_style.bg_color = get_theme_color("dark_color_2", "Editor")
	exts_style.corner_radius_top_left = 6
	exts_style.corner_radius_top_right = 6
	exts_style.corner_radius_bottom_left = 6
	exts_style.corner_radius_bottom_right = 6
	allowed_exts_edit.add_theme_stylebox_override("normal", exts_style)
	allowed_exts_edit.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	content.add_child(allowed_exts_edit)

	# === Extension Management ===
	_add_section_header(content, "Extension Management")
	
	# Extension Management Header Buttons
	var h_ext_header = HBoxContainer.new()
	content.add_child(h_ext_header)
	
	var lbl_ext_hint = Label.new()
	lbl_ext_hint.text = "Manage installed search extensions"
	lbl_ext_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_ext_hint.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
	lbl_ext_hint.add_theme_font_size_override("font_size", 12)
	h_ext_header.add_child(lbl_ext_hint)
	
	var btn_import = Button.new()
	btn_import.text = "Import Extension (.gd)"
	btn_import.icon = get_theme_icon("Load", "EditorIcons")
	btn_import.pressed.connect(_on_import_extension_pressed)
	h_ext_header.add_child(btn_import)
	
	extensions_container = VBoxContainer.new()
	extensions_container.add_theme_constant_override("separation", 8)
	content.add_child(extensions_container)
	
	# === Footer Buttons ===
	main_vbox.add_child(_create_separator())
	
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	main_vbox.add_child(footer)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(queue_free)
	footer.add_child(btn_cancel)
	
	var btn_save = Button.new()
	btn_save.text = "Save"
	btn_save.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
	btn_save.pressed.connect(_on_save_pressed)
	footer.add_child(btn_save)

func _create_extension_card(ext):
	var ext_id = ext.get_id()
	var ext_name = ext.get_display_name()
	var is_enabled = SpotlightConfig.is_extension_enabled(ext_id)
	
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = get_theme_color("dark_color_2", "Editor") # Surface
	style.border_width_left = 3
	style.border_color = get_theme_color("success_color", "Editor") if is_enabled else get_theme_color("font_disabled_color", "Editor")
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	extensions_container.add_child(card)
	
	var hbox = HBoxContainer.new()
	card.add_child(hbox)
	
	var vbox_info = VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_info)
	
	var lbl_name = Label.new()
	lbl_name.text = ext_name
	lbl_name.add_theme_font_size_override("font_size", 14)
	lbl_name.add_theme_color_override("font_color", get_theme_color("font_color", "Editor"))
	vbox_info.add_child(lbl_name)
	
	# Metadata Container
	var h_meta = HBoxContainer.new()
	h_meta.add_theme_constant_override("separation", 8)
	vbox_info.add_child(h_meta)
	
	# Determine Type (Official vs Community)
	var script_path = ext.get_script().resource_path
	var is_official = script_path.begins_with("res://addons/spotlight_search/modules/") or script_path.begins_with("res://addons/spotlight_search/core/")
	var type_text = "Official" if is_official else "Community"
	var type_color = get_theme_color("accent_color", "Editor") if is_official else get_theme_color("success_color", "Editor")
	
	var lbl_type = Label.new()
	lbl_type.text = "[%s]" % type_text
	lbl_type.add_theme_font_size_override("font_size", 11)
	lbl_type.add_theme_color_override("font_color", type_color)
	h_meta.add_child(lbl_type)
	
	# Author
	var author = ext.get_author()
	if not author.is_empty():
		var lbl_auth = Label.new()
		lbl_auth.text = "by " + author
		lbl_auth.add_theme_font_size_override("font_size", 11)
		lbl_auth.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
		h_meta.add_child(lbl_auth)
	
	var lbl_id = Label.new()
	lbl_id.text = "ID: " + ext_id
	lbl_id.add_theme_font_size_override("font_size", 11)
	lbl_id.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
	vbox_info.add_child(lbl_id)
	
	# Remove button (only for external extensions)
	# Check if external extension by script path
	var external_paths = SpotlightConfig.get_external_extensions()
	
	if script_path in external_paths:
		var btn_remove = Button.new()
		btn_remove.icon = get_theme_icon("Remove", "EditorIcons")
		btn_remove.tooltip_text = "Remove this extension"
		btn_remove.flat = true
		btn_remove.pressed.connect(func(): _on_remove_extension_pressed(script_path))
		hbox.add_child(btn_remove)
	
	var toggle = CheckButton.new()
	toggle.text = "Enable"
	toggle.button_pressed = is_enabled
	toggle.toggled.connect(_on_extension_toggled.bind(ext_id, card))
	hbox.add_child(toggle)
	

func _load_values():
	# Load max results
	max_results_spin.value = SpotlightConfig.get_max_results()
	
	# Load max preview length
	max_preview_spin.value = SpotlightConfig.get_max_preview_length()
	
	# Load exclude patterns
	var patterns = SpotlightConfig.get_exclude_patterns()
	excludes_edit.text = "\n".join(patterns)
	
	# Load allowed extensions
	var exts = SpotlightConfig.get_allowed_extensions()
	allowed_exts_edit.text = "\n".join(exts)
	
	# Load shortcut
	current_shortcut = SpotlightConfig.get_shortcut()
	_update_shortcut_label()
	
	# Load extension list
	_refresh_extensions_list()

func _refresh_extensions_list():
	for child in extensions_container.get_children():
		child.queue_free()
	
	# Get all registered extensions from SpotlightManager
	var manager = Engine.get_main_loop().root.get_node_or_null("SpotlightManager")
	if not manager:
		var lbl = Label.new()
		lbl.text = "Cannot get extension list"
		lbl.add_theme_color_override("font_color", get_theme_color("error_color", "Editor"))
		extensions_container.add_child(lbl)
		return
	
	var extensions = manager.get_all_extensions()
	if extensions.is_empty():
		var lbl = Label.new()
		lbl.text = "No registered extensions"
		lbl.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
		extensions_container.add_child(lbl)
		return
	
	for ext in extensions:
		_create_extension_card(ext)


func _on_extension_toggled(enabled: bool, ext_id: String, card: PanelContainer):
	SpotlightConfig.set_extension_enabled(ext_id, enabled)
	
	# Update card style
	var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = get_theme_color("success_color", "Editor") if enabled else get_theme_color("font_disabled_color", "Editor")
	card.add_theme_stylebox_override("panel", style)

func _on_import_extension_pressed():
	var fd = EditorFileDialog.new()
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.filters = ["*.gd ; GDScript Extension"]
	fd.file_selected.connect(_on_extension_file_selected)
	# Must add to tree to show
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_file_dialog()

func _on_extension_file_selected(path: String):
	print("[Spotlight] adding external extension: ", path)
	SpotlightConfig.add_external_extension(path)
	
	# Try to load immediately
	var manager = Engine.get_main_loop().root.get_node_or_null("SpotlightManager")
	if manager:
		manager._load_and_register_external(path)
		
	# Refresh list
	_refresh_extensions_list()

func _on_remove_extension_pressed(path: String):
	SpotlightConfig.remove_external_extension(path)
	
	# Refresh list
	# Try to unregister from Manager
	var manager = Engine.get_main_loop().root.get_node_or_null("SpotlightManager")
	if manager:
		manager.unregister_extension(path)
	
	_refresh_extensions_list()
	
	print("[Spotlight] Removed extension path: ", path)

func _on_save_pressed():
	# Save max results
	SpotlightConfig.set_max_results(int(max_results_spin.value))
	
	# Save max preview length
	SpotlightConfig.set_max_preview_length(int(max_preview_spin.value))
	
	# Save exclude patterns
	var lines = excludes_edit.text.split("\n", false)
	var packed = PackedStringArray()
	for line in lines:
		var s = line.strip_edges()
		if s != "":
			packed.append(s)
	SpotlightConfig.set_exclude_patterns(packed)
	
	# Save allowed extensions
	var ext_lines = allowed_exts_edit.text.split("\n", false)
	var ext_packed = PackedStringArray()
	for line in ext_lines:
		var s = line.strip_edges()
		if s != "":
			if s.begins_with("."): s = s.substr(1)
			ext_packed.append(s)
	SpotlightConfig.set_allowed_extensions(ext_packed)
	
	# Save shortcut
	SpotlightConfig.set_shortcut(current_shortcut)

	
	print("[Spotlight] Settings saved")
	queue_free()

func _add_section_header(parent: Control, text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
	parent.add_child(lbl)

func _create_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.2)
	return sep

func _on_shortcut_btn_toggled(pressed: bool):
	listening_for_input = pressed
	if pressed:
		shortcut_btn.text = "Press shortcut..."
		shortcut_label.text = "Waiting for input..."
	else:
		shortcut_btn.text = "Click to Set"
		_update_shortcut_label()

func _input(event):
	if not listening_for_input: return
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Ignore standalone modifier keys
		if event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
			return
			
		# Capture shortcut
		current_shortcut = {
			"keycode": event.keycode,
			"ctrl_pressed": event.ctrl_pressed,
			"shift_pressed": event.shift_pressed,
			"alt_pressed": event.alt_pressed,
			"meta_pressed": event.meta_pressed
		}
		
		# Stop listening
		listening_for_input = false
		shortcut_btn.button_pressed = false
		shortcut_btn.text = "Click to Set"
		_update_shortcut_label()
		
		get_viewport().set_input_as_handled()

func _update_shortcut_label():
	if current_shortcut.is_empty():
		shortcut_label.text = "None"
		return
		
	var parts = []
	if current_shortcut.get("ctrl_pressed", false): parts.append("Ctrl")
	if current_shortcut.get("shift_pressed", false): parts.append("Shift")
	if current_shortcut.get("alt_pressed", false): parts.append("Alt")
	if current_shortcut.get("meta_pressed", false): parts.append("Meta")
	
	var keycode = current_shortcut.get("keycode", 0)
	if keycode > 0:
		parts.append(OS.get_keycode_string(keycode))
		
	shortcut_label.text = "+".join(parts)
