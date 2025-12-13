@tool
extends PopupPanel

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
const SearchLogic = preload("res://addons/spotlight_search/services/search_logic.gd")
const ResultItem = preload("res://addons/spotlight_search/ui/result_item.gd")
const QueryService = preload("res://addons/spotlight_search/services/query_service.gd")
const ActionService = preload("res://addons/spotlight_search/services/action_service.gd")
const ContextMenuService = preload("res://addons/spotlight_search/services/context_menu_service.gd")
const SpotlightTheme = preload("res://addons/spotlight_search/ui/spotlight_theme.gd")
const ConfigWindow = preload("res://addons/spotlight_search/ui/config_window.gd")
const HistoryManager = preload("res://addons/spotlight_search/managers/history_manager.gd")
const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")

@onready var search_bar = $VBoxContainer/SearchBar
@onready var result_list = $VBoxContainer/ScrollContainer/ResultList
@onready var scroll_container = $VBoxContainer/ScrollContainer
@onready var info_label = $VBoxContainer/Label

var logic = SearchLogic.new()
var query_service: QueryService
var action_service: ActionService
var context_menu_service: ContextMenuService

var current_selection_index: int = 0
var context_menu: PopupMenu
var context_target: SearchData
var _last_toast_type: String = ""

# Animation helpers
var _target_height: float = 450.0

# ===== 生命周期 ======
func _ready():
	# Styling
	add_theme_stylebox_override("panel", SpotlightTheme.get_main_stylebox())
	
	query_service = QueryService.new(logic)
	action_service = ActionService.new(logic)
	context_menu_service = ContextMenuService.new(logic)
	
	var vbox = $VBoxContainer
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12) # More breathing room
	
	# Search Bar styling
	var search_style = SpotlightTheme.get_search_bar_stylebox()
	search_bar.add_theme_stylebox_override("normal", search_style)
	search_bar.add_theme_stylebox_override("focus", search_style)
	search_bar.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	search_bar.add_theme_font_size_override("font_size", SpotlightTheme.FONT_SIZE_LARGE)
	search_bar.placeholder_text = TranslationService.get_string("placeholder_search")
	
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_list.add_theme_constant_override("separation", 4)
	
	# Info label styling
	info_label.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
	info_label.add_theme_font_size_override("font_size", SpotlightTheme.FONT_SIZE_SMALL)
	
	search_bar.text_changed.connect(_on_search_text_changed)
	search_bar.gui_input.connect(_on_search_bar_input)
	
	logic.load_history()
	_setup_context_menu()
	
	var fs = EditorInterface.get_resource_filesystem()
	if not fs.filesystem_changed.is_connected(_on_fs_changed):
		fs.filesystem_changed.connect(_on_fs_changed)
	
	logic.scan_completed.connect(_on_scan_completed)
	
	_setup_progress_bar()

func _exit_tree():
	if context_menu: context_menu.queue_free()

var _initial_scan_done = false
var _progress_bar: ProgressBar

func _setup_progress_bar():
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 4
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.show_percentage = false
	_progress_bar.visible = false
	
	# Style the progress bar
	var bg = StyleBoxFlat.new()
	bg.bg_color = SpotlightTheme.COL_SURFACE
	bg.corner_radius_top_left = 2; bg.corner_radius_bottom_left = 2
	bg.corner_radius_top_right = 2; bg.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("background", bg)
	
	var fg = StyleBoxFlat.new()
	fg.bg_color = SpotlightTheme.COL_ACCENT
	fg.corner_radius_top_left = 2; fg.corner_radius_bottom_left = 2
	fg.corner_radius_top_right = 2; fg.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("fill", fg)
	
	# Insert after SearchBar
	$VBoxContainer.add_child(_progress_bar)
	$VBoxContainer.move_child(_progress_bar, 1)

func _on_fs_changed(): 
	if _initial_scan_done and is_inside_tree():
		logic.scan_filesystem()

func _on_scan_completed(): 
	if not _initial_scan_done:
		_initial_scan_done = true
		_progress_bar.value = 100
		
		# Allow the progress bar to show completion for a brief moment
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree(): return
		
		_progress_bar.visible = false
		result_list.visible = true
		search_bar.editable = true
		search_bar.placeholder_text = TranslationService.get_string("placeholder_search")
		search_bar.grab_focus()
		
		_update_results(search_bar.text)
		_update_target_hint()
	else:
		_update_results(search_bar.text)

func popup_custom():
	if not _initial_scan_done:
		_start_initial_scan()
	else:
		logic.scan_filesystem()
		search_bar.clear()
		search_bar.grab_focus()
		_update_results("") # This will now use the freshly scanned data
		_update_target_hint()
		
	var mouse = DisplayServer.mouse_get_position()
	self.size = Vector2i(700, int(_target_height))
	self.position = _calculate_safe_pos(mouse)
	
	# Reset state for animation
	$VBoxContainer.modulate.a = 0.0
	var original_y = self.position.y
	self.position.y -= 20
	
	self.popup()
	search_bar.grab_focus()
	
	# Animation
	var tween = create_tween().set_parallel(true)
	tween.tween_property($VBoxContainer, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:y", float(original_y), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _start_initial_scan():
	search_bar.editable = false
	search_bar.placeholder_text = TranslationService.get_string("placeholder_initializing")
	result_list.visible = false
	_progress_bar.visible = true
	_progress_bar.value = 0
	
	# Simulate progress for visual feedback
	var tween = create_tween()
	tween.tween_property(_progress_bar, "value", 90.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	logic.scan_filesystem()

func _update_target_hint():
	var root = EditorInterface.get_edited_scene_root()
	var sel = EditorInterface.get_selection().get_selected_nodes()
	
	var target_name = "PopupPanel"
	if sel:
		target_name = sel[0].name
	elif root:
		target_name = root.name
	
	info_label.text = TranslationService.get_string("info_default", [target_name])

func _teleport():
	var mouse = DisplayServer.mouse_get_position()
	var final_pos = _calculate_safe_pos(mouse)
	
	# Teleport Animation (Fade Out -> Move -> Fade In)
	var tween = create_tween()
	tween.tween_property($VBoxContainer, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): 
		self.position = final_pos
		search_bar.grab_focus()
	)
	tween.tween_property($VBoxContainer, "modulate:a", 1.0, 0.15)

func _calculate_safe_pos(mouse_pos: Vector2i) -> Vector2i:
	var target = mouse_pos - Vector2i(350, 20)
	var screen_id = DisplayServer.get_screen_from_rect(Rect2(mouse_pos, Vector2(1, 1)))
	var rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	if target.x < rect.position.x: target.x = rect.position.x
	elif target.x + self.size.x > rect.end.x: target.x = rect.end.x - self.size.x
	if target.y < rect.position.y: target.y = rect.position.y
	elif target.y + self.size.y > rect.end.y: target.y = rect.end.y - self.size.y
	return target

func _on_search_text_changed(txt): _update_results(txt)

func _update_results(query: String):
	_clear_ui()
	
	# Use QueryService to get results
	var results = query_service.process_query(query)
	
	var count = 0
	for item in results:
		_create_item_ui(item, count == 0)
		count += 1

func _clear_ui():
	for c in result_list.get_children(): c.queue_free()
	current_selection_index = 0

func _create_item_ui(data: SearchData, sel: bool):
	var btn = ResultItem.new(data)
	btn.set_highlight(sel)
	btn.item_pressed.connect(func(_d): _execute(data))
	
	if data.type != SearchData.Type.COMMAND and data.type != SearchData.Type.ACTION and data.type != SearchData.Type.CREATE_ACTION:
		btn.right_clicked.connect(_on_right_click)
		
	result_list.add_child(btn)

func _execute(data: SearchData, shift: bool = false, only_autocomplete: bool = false):
	if only_autocomplete:
		var text_to_insert = ""
		if data.type == SearchData.Type.COMMAND:
			text_to_insert = data.file_path
		elif data.type == SearchData.Type.ACTION:
			text_to_insert = data.file_name 
			
		if text_to_insert != "":
			search_bar.text = text_to_insert + " "
			search_bar.caret_column = search_bar.text.length()
			_update_results(search_bar.text)
		return

	# 2. Command Drill-down
	if data.type == SearchData.Type.COMMAND:
		var cmd_text = data.file_path if not data.file_path.is_empty() else data.file_name
		search_bar.text = cmd_text + " "
		search_bar.caret_column = search_bar.text.length()
		_update_results(search_bar.text)
		return
		
	# 3. Handle Toast Error
	if data.file_path == "toast_error":
		var msg = data.args[0] if not data.args.is_empty() else "Unknown Error"
		show_toast(msg, "error")
		return
	
	# 4. Delegate to ActionService
	_last_toast_type = "" # Reset toast state
	
	# Save command to history (for actions, save the command chain)
	if data.type == SearchData.Type.ACTION and data.file_name.begins_with("-"):
		HistoryManager.add_to_history(data.file_name)
	
	var should_close = await action_service.execute(data, shift)
	
	# Only close if requested AND no warning/error toast was shown
	if should_close and _last_toast_type != "warning" and _last_toast_type != "error":
		self.hide()

func show_toast(message: String, type: String = "info"):
	_last_toast_type = type
	
	# Create a dedicated Popup (Window) for the toast to float independently
	var toast_win = Window.new()
	
	toast_win.borderless = true
	toast_win.unfocusable = true 
	toast_win.always_on_top = true
	toast_win.mouse_passthrough = true
	
	toast_win.size = Vector2(300, 50) 
	toast_win.transparent = true
	toast_win.transparent_bg = true
	
	var toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 10; style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	
	if type == "error": style.bg_color = SpotlightTheme.COL_ERROR
	elif type == "success": style.bg_color = SpotlightTheme.COL_SUCCESS
	elif type == "warning": style.bg_color = SpotlightTheme.COL_WARNING
	else: style.bg_color = SpotlightTheme.COL_SURFACE_LIGHT
	
	# Keep opacity high
	style.bg_color.a = 1.0 
	
	toast_panel.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if type in ["success", "warning"]:
		lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	else:
		lbl.add_theme_color_override("font_color", Color.WHITE)
		
	toast_panel.add_child(lbl)
	toast_win.add_child(toast_panel)
	
	EditorInterface.get_base_control().add_child(toast_win)
	
	# Calculate size and position
	var font = lbl.get_theme_font("font")
	var font_size = lbl.get_theme_font_size("font_size")
	var text_size = font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var win_size = text_size + Vector2(40, 20)
	toast_win.size = win_size
	
	# Position at bottom center of the spotlight window if visible, else screen bottom
	var target_pos = Vector2()
	if self.visible:
		target_pos = Vector2(self.position) + Vector2(self.size.x / 2 - win_size.x / 2, self.size.y - win_size.y - 40)
	else:
		# Fallback to center of screen or mouse
		var mouse = Vector2(DisplayServer.mouse_get_position())
		target_pos = mouse - win_size / 2
		
	toast_win.position = Vector2i(target_pos)
	toast_win.show()
	
	# Animation
	toast_panel.modulate.a = 0.0
	var tween = toast_win.create_tween()
	tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	# Wait reading time
	tween.tween_interval(2.0)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast_win.queue_free)

func _setup_context_menu():
	context_menu = PopupMenu.new()
	add_child(context_menu)
	context_menu.id_pressed.connect(_on_context_menu_item_pressed)

func _on_context_menu_item_pressed(idx):
	var id = context_menu.get_item_metadata(idx)
	context_menu_service.handle_action(id, context_target)
	if id == "toggle_pin":
		_update_results(search_bar.text)

func _on_right_click(data: SearchData, pos: Vector2):
	context_target = data
	context_menu.clear()
	
	var config = context_menu_service.get_menu_config(data)
	if config.is_empty(): return
	
	for item in config:
		if item.has("type") and item.type == "separator":
			context_menu.add_separator()
			continue
			
		var label = item.label
		if item.id == "toggle_pin":
			label = TranslationService.get_string("ctx_unpin") if logic.is_pinned(data.file_path) else TranslationService.get_string("ctx_pin")
			
		context_menu.add_item(label)
		var idx = context_menu.get_item_count() - 1
		context_menu.set_item_metadata(idx, item.id)
		
				
	context_menu.position = pos
	context_menu.popup()

func _on_search_bar_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_container.scroll_vertical -= 40
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_container.scroll_vertical += 40
			
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q and event.alt_pressed:
			_teleport()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP and event.shift_pressed:
			# Shift+Up: Show command history
			if search_bar.text.strip_edges().is_empty():
				_show_history()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			_move_sel(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_move_sel(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT and event.shift_pressed:
			# Toggle context menu for current selection (Shift+Right)
			if context_menu.visible:
				context_menu.hide()
				search_bar.grab_focus()
			else:
				if result_list.get_child_count() > 0:
					var item = result_list.get_child(current_selection_index)
					if item.data.type != SearchData.Type.COMMAND and item.data.type != SearchData.Type.ACTION:
						var pos = item.get_screen_position() + Vector2(item.size.x - 50, item.size.y / 2)
						_on_right_click(item.data, pos)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_LEFT and event.shift_pressed:
			# TODO：【not useful】Close context menu if open (Shift+Left)
			if context_menu and context_menu.is_visible():
				context_menu.hide()
				search_bar.grab_focus.call_deferred()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_ESCAPE:
			# Close context menu first, or close window if menu is closed
			if context_menu.visible:
				context_menu.hide()
				search_bar.grab_focus()
			else:
				self.hide()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			if result_list.get_child_count() > 0:
				var item = result_list.get_child(current_selection_index)
				_execute(item.data, false, true) # Autocomplete only
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if result_list.get_child_count() > 0:
				var item = result_list.get_child(current_selection_index)
				_execute(item.data, event.shift_pressed, false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and event.alt_pressed:
			if result_list.get_child_count() > 0:
				var item = result_list.get_child(current_selection_index)
				if item.data.type == SearchData.Type.COMMAND and item.data.file_path.begins_with("-"):
					var cmd = item.data.file_path
					var is_now_fav = HistoryManager.toggle_favorite(cmd)
					if is_now_fav:
						show_toast(TranslationService.get_string("toast_favorite_added"), "success")
					else:
						show_toast(TranslationService.get_string("toast_favorite_removed"), "info")
					_show_history()
					get_viewport().set_input_as_handled()

func _move_sel(dir):
	var count = result_list.get_child_count()
	if count == 0: return
	result_list.get_child(current_selection_index).set_highlight(false)
	current_selection_index = wrap(current_selection_index + dir, 0, count)
	var next = result_list.get_child(current_selection_index)
	next.set_highlight(true)
	_ensure_visible(next)

func _ensure_visible(ctrl):
	var scroll_v = scroll_container.scroll_vertical
	var c_y = ctrl.position.y
	var c_h = ctrl.size.y
	var s_h = scroll_container.size.y
	if c_y < scroll_v: scroll_container.scroll_vertical = c_y
	elif c_y + c_h > scroll_v + s_h: scroll_container.scroll_vertical = c_y + c_h - s_h

func _show_history():
	for child in result_list.get_children():
		child.queue_free()
	
	var history = HistoryManager.get_recent(10)
	var favorites = HistoryManager.get_favorites()
	
	for cmd in favorites:
		var item = SearchData.new()
		item.type = SearchData.Type.COMMAND
		item.file_name = "★ " + cmd
		item.file_path = cmd
		item.desc = TranslationService.get_string("history_favorite")
		item.icon_name = "Favorites"
		item.score = 2000
		_create_item_ui(item, result_list.get_child_count() == 0)
	
	for cmd in history:
		if cmd in favorites: continue
		var item = SearchData.new()
		item.type = SearchData.Type.COMMAND
		item.file_name = cmd
		item.file_path = cmd
		item.desc = TranslationService.get_string("history_recent")
		item.icon_name = "History"
		item.score = 1000
		_create_item_ui(item, result_list.get_child_count() == 0)
	
	if result_list.get_child_count() == 0:
		var item = SearchData.new()
		item.type = SearchData.Type.COMMAND
		item.file_name = TranslationService.get_string("history_empty")
		item.file_path = ""
		item.desc = TranslationService.get_string("history_empty_desc")
		item.icon_name = "Info"
		_create_item_ui(item, true)
	
	current_selection_index = 0
	info_label.text = TranslationService.get_string("info_history")
