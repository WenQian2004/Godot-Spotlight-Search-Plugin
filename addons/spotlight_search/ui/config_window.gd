@tool
extends Window

const ConfigManager = preload("res://addons/spotlight_search/managers/config_manager.gd")
const CommandManager = preload("res://addons/spotlight_search/managers/command_manager.gd")
const SpotlightTheme = preload("res://addons/spotlight_search/ui/spotlight_theme.gd")
const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")

var max_results_spin: SpinBox
var excludes_edit: TextEdit
var key_btn: Button
var alt_box: CheckBox
var ctrl_box: CheckBox
var shift_box: CheckBox
var lang_dropdown: OptionButton

var config_container: VBoxContainer
var file_dialog: FileDialog

var listening_input: bool = false
var current_keycode: int

func _ready():
	title = TranslationService.get_string("config_title")
	add_to_group("spotlight_config_window")
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(700, 650)
	unresizable = false
	close_requested.connect(queue_free)
	
	_build_ui()
	_load_values()

func _build_ui():
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Apply main theme style
	panel.add_theme_stylebox_override("panel", SpotlightTheme.get_main_stylebox())
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	margin.add_child(vbox)
	
	# Header
	var header = Label.new()
	header.text = TranslationService.get_string("config_header")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	vbox.add_child(header)
	
	var hs_top = HSeparator.new()
	hs_top.modulate = SpotlightTheme.COL_BORDER
	vbox.add_child(hs_top)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	scroll.add_child(content)
	
	_add_section_header(content, TranslationService.get_string("config_general"))
	
	var h_lang = HBoxContainer.new()
	content.add_child(h_lang)
	var lbl_lang = Label.new()
	lbl_lang.text = TranslationService.get_string("config_language")
	lbl_lang.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	lbl_lang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_lang.add_child(lbl_lang)
	
	lang_dropdown = OptionButton.new()
	for lang in TranslationService.get_available_languages():
		lang_dropdown.add_item(TranslationService.get_language_name(lang))
	h_lang.add_child(lang_dropdown)
	
	var h_res = HBoxContainer.new()
	content.add_child(h_res)
	var lbl_res = Label.new()
	lbl_res.text = TranslationService.get_string("config_max_results")
	lbl_res.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	lbl_res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_res.add_child(lbl_res)
	
	max_results_spin = SpinBox.new()
	max_results_spin.min_value = 1
	max_results_spin.max_value = 100
	h_res.add_child(max_results_spin)
	
	# 2. Scope Settings
	_add_section_header(content, TranslationService.get_string("config_search_scope"))
	
	var lbl_ex = Label.new()
	lbl_ex.text = TranslationService.get_string("config_exclude_folders")
	lbl_ex.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
	content.add_child(lbl_ex)
	
	excludes_edit = TextEdit.new()
	excludes_edit.custom_minimum_size = Vector2(0, 100)
	excludes_edit.placeholder_text = "addons/\n.git/"
	# Style the TextEdit
	var style_input = StyleBoxFlat.new()
	style_input.bg_color = SpotlightTheme.COL_SURFACE
	style_input.corner_radius_top_left = 6; style_input.corner_radius_top_right = 6;
	style_input.corner_radius_bottom_left = 6; style_input.corner_radius_bottom_right = 6;
	excludes_edit.add_theme_stylebox_override("normal", style_input)
	excludes_edit.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	content.add_child(excludes_edit)
	
	# 3. Shortcuts
	_add_section_header(content, TranslationService.get_string("config_shortcuts"))
	
	var h_key = HBoxContainer.new()
	content.add_child(h_key)
	var lbl_key = Label.new()
	lbl_key.text = TranslationService.get_string("config_activation_key")
	lbl_key.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	lbl_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_key.add_child(lbl_key)
	
	key_btn = Button.new()
	key_btn.text = TranslationService.get_string("config_press_to_set")
	key_btn.pressed.connect(_on_key_btn_pressed)
	h_key.add_child(key_btn)
	
	var h_mod = HBoxContainer.new()
	content.add_child(h_mod)
	h_mod.alignment = BoxContainer.ALIGNMENT_END
	
	alt_box = CheckBox.new()
	alt_box.text = "Alt"
	h_mod.add_child(alt_box)
	
	ctrl_box = CheckBox.new()
	ctrl_box.text = "Ctrl"
	h_mod.add_child(ctrl_box)
	
	shift_box = CheckBox.new()
	shift_box.text = "Shift"
	h_mod.add_child(shift_box)
	
	# 4. Imported Configuration Modules
	_add_section_header(content, TranslationService.get_string("config_imported"))
	
	var h_tools = HBoxContainer.new()
	content.add_child(h_tools)
	
	var btn_import = Button.new()
	btn_import.text = TranslationService.get_string("config_import_json")
	btn_import.pressed.connect(_on_import_pressed)
	h_tools.add_child(btn_import)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_tools.add_child(spacer)
	
	var btn_reload = Button.new()
	btn_reload.text = TranslationService.get_string("config_reload_all")
	btn_reload.pressed.connect(_on_reload_commands_pressed)
	h_tools.add_child(btn_reload)
	
	config_container = VBoxContainer.new()
	config_container.add_theme_constant_override("separation", 8)
	content.add_child(config_container)
	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.json ; " + TranslationService.get_string("config_json_filter")]
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	# 5. Extensions
	_add_section_header(content, TranslationService.get_string("config_extensions"))
	
	var lbl_ext_info = Label.new()
	lbl_ext_info.text = TranslationService.get_string("config_ext_info")
	lbl_ext_info.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
	lbl_ext_info.add_theme_font_size_override("font_size", 12)
	content.add_child(lbl_ext_info)
	
	var h_ext = HBoxContainer.new()
	content.add_child(h_ext)
	
	var btn_create_example = Button.new()
	btn_create_example.text = TranslationService.get_string("config_create_example")
	btn_create_example.icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	btn_create_example.pressed.connect(_on_create_example_pressed)
	h_ext.add_child(btn_create_example)
	
	var lbl_ext_hint = Label.new()
	lbl_ext_hint.text = TranslationService.get_string("config_ext_hint")
	lbl_ext_hint.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
	lbl_ext_hint.add_theme_font_size_override("font_size", 12)
	h_ext.add_child(lbl_ext_hint)
	
	# 6. Maintenance
	_add_section_header(content, TranslationService.get_string("config_maintenance"))
	
	var h_maint = HBoxContainer.new()
	content.add_child(h_maint)
	
	var btn_clear = Button.new()
	btn_clear.text = TranslationService.get_string("config_clear_cache")
	btn_clear.pressed.connect(_on_clear_cache_pressed)
	h_maint.add_child(btn_clear)
	
	# Footer
	var hs_bot = HSeparator.new()
	hs_bot.modulate = SpotlightTheme.COL_BORDER
	vbox.add_child(hs_bot)
	
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 20)
	vbox.add_child(footer)
	
	var btn_cancel = Button.new()
	btn_cancel.text = TranslationService.get_string("config_cancel")
	btn_cancel.pressed.connect(queue_free)
	footer.add_child(btn_cancel)
	
	var btn_save = Button.new()
	btn_save.text = TranslationService.get_string("config_save")
	btn_save.add_theme_color_override("font_color", SpotlightTheme.COL_ACCENT)
	btn_save.pressed.connect(_on_save_pressed)
	footer.add_child(btn_save)

func _on_import_pressed():
	file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String):
	if path.strip_edges().is_empty() or path == "res://" or path == "res:/":
		print("[Spotlight] Invalid config path selected.")
		return
		
	ConfigManager.add_external_config(path)
	_on_reload_commands_pressed()

func _on_create_example_pressed():
	var ext_dir = "res://toolkit_extensions/"
	var json_path = ext_dir + "hello_extension.json"
	var gd_path = ext_dir + "hello_actions.gd"
	
	# Check if already exists
	if FileAccess.file_exists(json_path):
		var dlg = AcceptDialog.new()
		dlg.title = "Extension Already Exists"
		dlg.dialog_text = "The Hello extension already exists at:\n" + json_path + "\n\nDelete it first if you want to recreate."
		dlg.confirmed.connect(dlg.queue_free)
		add_child(dlg)
		dlg.popup_centered()
		return
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(ext_dir):
		DirAccess.make_dir_recursive_absolute(ext_dir)
	
	# Copy example files from addon data
	var src_json = "res://addons/spotlight_search/data/examples/hello_extension.json"
	var src_gd = "res://addons/spotlight_search/data/examples/hello_actions.gd"
	
	var err1 = _copy_file(src_json, json_path)
	var err2 = _copy_file(src_gd, gd_path)
	
	if err1 == OK and err2 == OK:
		print("[Spotlight] Created example extension at: " + ext_dir)
		
		# Automatically import the created extension
		ConfigManager.add_external_config(json_path)
		CommandManager.load_all_commands(true)
		_refresh_config_list()
		
		# Show success dialog
		var dlg = AcceptDialog.new()
		dlg.title = "Example Extension Created & Imported"
		dlg.dialog_text = "Created and imported Hello World extension!\n\nFiles:\n• " + json_path + "\n• " + gd_path + "\n\nTry typing '-hello' in Spotlight!"
		dlg.confirmed.connect(dlg.queue_free)
		add_child(dlg)
		dlg.popup_centered()
	else:
		push_warning("[Spotlight] Failed to create example extension")

func _copy_file(src: String, dst: String) -> Error:
	if not FileAccess.file_exists(src):
		push_warning("[Spotlight] Source file not found: " + src)
		return ERR_FILE_NOT_FOUND
	
	var content = FileAccess.get_file_as_string(src)
	var file = FileAccess.open(dst, FileAccess.WRITE)
	if not file:
		return ERR_CANT_CREATE
	file.store_string(content)
	file.close()
	return OK

func _on_clear_cache_pressed():
	var dlg = ConfirmationDialog.new()
	dlg.title = "Clear Imported Configurations"
	dlg.dialog_text = "This will remove all imported JSON configurations.\n\nNote: Extensions in 'toolkit_extensions/' and system commands will remain.\n\nContinue?"
	dlg.confirmed.connect(func(): 
		ConfigManager.clear_all_external_configs()
		CommandManager.load_all_commands(true)
		print("[Spotlight] Imported configurations cleared.")
		_refresh_config_list()
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()

func _on_reload_commands_pressed():
	CommandManager.load_all_commands(true)
	_refresh_config_list()

func _refresh_config_list():
	for child in config_container.get_children():
		child.queue_free()
		
	# 1. Show all loaded non-system configs
	var loaded_paths = []
	for cfg in CommandManager.LOADED_CONFIGS:
		# Skip system configs (they're hidden from UI)
		if cfg.get("is_system", false):
			continue
			
		_create_config_card(cfg)
		loaded_paths.append(cfg.get("path", ""))
		
	# 2. Show disabled external configs (not loaded but registered)
	var externals = ConfigManager.get_external_configs()
	if externals is Dictionary:
		for path in externals:
			if path in loaded_paths: continue
			if path.strip_edges().is_empty(): continue
			
			# Create a dummy config object for display
			var dummy_cfg = {
				"path": path,
				"status": "disabled",
				"meta": { "name": path.get_file() },
				"command_count": 0
			}
			_create_config_card(dummy_cfg)

func _create_config_card(cfg: Dictionary):
	var path = cfg.get("path", "Unknown")
	var status = cfg.get("status", "error")
	var meta = cfg.get("meta", {})
	var name = meta.get("name", path.get_file())
	var ver = meta.get("version", "")
	var count = cfg.get("command_count", 0)
	var is_enabled = (status == "ok")
	
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = SpotlightTheme.COL_SURFACE
	style.border_width_left = 4 
	style.border_color = SpotlightTheme.COL_SUCCESS if status == "ok" else (SpotlightTheme.COL_TEXT_DIM if status == "disabled" else SpotlightTheme.COL_ERROR)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_left = 2
	
	card.add_theme_stylebox_override("panel", style)
	config_container.add_child(card)
	
	var hbox = HBoxContainer.new()
	card.add_child(hbox)
	
	var vbox_info = VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_info)
	
	var lbl_name = Label.new()
	lbl_name.text = name + (" v" + ver if ver else "")
	lbl_name.add_theme_font_size_override("font_size", 16)
	lbl_name.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	vbox_info.add_child(lbl_name)
	
	var lbl_path = Label.new()
	lbl_path.text = path
	lbl_path.add_theme_font_size_override("font_size", 12)
	lbl_path.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
	lbl_path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox_info.add_child(lbl_path)
	
	var lbl_status = Label.new()
	if status == "error":
		lbl_status.text = TranslationService.get_string("config_status_error") + cfg.get("error_msg", "Unknown error")
		lbl_status.add_theme_color_override("font_color", SpotlightTheme.COL_ERROR)
	elif status == "disabled":
		lbl_status.text = TranslationService.get_string("config_status_disabled")
		lbl_status.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
	else:
		lbl_status.text = TranslationService.get_string("config_status_commands", [count])
		lbl_status.add_theme_color_override("font_color", SpotlightTheme.COL_SUCCESS)
	lbl_status.add_theme_font_size_override("font_size", 12)
	vbox_info.add_child(lbl_status)
	
	# Actions
	var vbox_actions = VBoxContainer.new()
	hbox.add_child(vbox_actions)
	
	var toggle = CheckButton.new()
	toggle.text = TranslationService.get_string("config_enabled")
	toggle.button_pressed = is_enabled
	toggle.toggled.connect(_on_config_toggled.bind(path))
	vbox_actions.add_child(toggle)
	
	var btn_remove = Button.new()
	btn_remove.text = TranslationService.get_string("config_remove")
	btn_remove.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_remove.pressed.connect(_on_remove_config.bind(path))
	vbox_actions.add_child(btn_remove)

func _on_config_toggled(enabled: bool, path: String):
	ConfigManager.set_external_config_enabled(path, enabled)
	# Reload to reflect changes
	CommandManager.load_all_commands(true)
	_refresh_config_list()

func _on_remove_config(path: String):
	ConfigManager.remove_external_config(path)
	CommandManager.load_all_commands(true)
	_refresh_config_list()

func _add_section_header(parent: Control, text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", SpotlightTheme.COL_ACCENT)
	parent.add_child(lbl)
	var hs = HSeparator.new()
	hs.modulate = SpotlightTheme.COL_BORDER
	parent.add_child(hs)

func _load_values():
	max_results_spin.value = ConfigManager.get_max_results()
	
	var patterns = ConfigManager.get_exclude_patterns()
	excludes_edit.text = "\n".join(patterns)
	
	var sc = ConfigManager.get_shortcut_config()
	current_keycode = sc.keycode
	_update_key_display()
	
	alt_box.button_pressed = sc.alt
	ctrl_box.button_pressed = sc.ctrl
	shift_box.button_pressed = sc.shift
	
	var current_lang = TranslationService.get_current_language()
	var langs = TranslationService.get_available_languages()
	for i in range(langs.size()):
		if langs[i] == current_lang:
			lang_dropdown.select(i)
			break
	
	_refresh_config_list()

func _on_key_btn_pressed():
	listening_input = true
	key_btn.text = TranslationService.get_string("config_listening")
	set_process_input(true)

func _input(event):
	if not listening_input: return
	
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
			return
			
		current_keycode = event.keycode
		listening_input = false
		_update_key_display()
		get_viewport().set_input_as_handled()

func _update_key_display():
	key_btn.text = OS.get_keycode_string(current_keycode)

func _on_save_pressed():
	ConfigManager.set_max_results(int(max_results_spin.value))
	
	var lines = excludes_edit.text.split("\n", false)
	var packed = PackedStringArray()
	for line in lines:
		var s = line.strip_edges()
		if s != "" and s != "res://" and s != "res:/": 
			packed.append(s)
	ConfigManager.set_exclude_patterns(packed)
	
	ConfigManager.set_shortcut(
		current_keycode,
		alt_box.button_pressed,
		ctrl_box.button_pressed,
		shift_box.button_pressed
	)
	
	var langs = TranslationService.get_available_languages()
	var selected_idx = lang_dropdown.get_selected_id()
	if selected_idx >= 0 and selected_idx < langs.size():
		TranslationService.set_language(langs[selected_idx])
	
	print("[Spotlight] Configuration saved.")
	queue_free()

func _exit_tree():
	listening_input = false
