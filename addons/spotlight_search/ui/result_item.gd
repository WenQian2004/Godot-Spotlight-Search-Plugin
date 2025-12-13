@tool
extends PanelContainer

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
const SpotlightTheme = preload("res://addons/spotlight_search/ui/spotlight_theme.gd")

signal item_pressed(data)
signal right_clicked(data, global_pos)

var data: SearchData
var _hbox: HBoxContainer
var _icon_rect: TextureRect
var _content_vbox: VBoxContainer
var _name_lbl: Label
var _desc_lbl: Label
var _tag_panel: PanelContainer
var _tag_lbl: Label
var _arrow_icon: TextureRect

var is_selected: bool = false
var is_hovered: bool = false

func _init(p_data: SearchData):	
	data = p_data
	custom_minimum_size.y = SpotlightTheme.ITEM_HEIGHT
	# Ensure PanelContainer receives mouse events for drag/drop
	mouse_filter = Control.MOUSE_FILTER_PASS 
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", SpotlightTheme.get_item_stylebox(false, false))
	_setup_ui()

func _setup_ui():
	# Inner margin handled by stylebox
	
	_hbox = HBoxContainer.new()
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # Important for Drag & Drop
	_hbox.add_theme_constant_override("separation", 12)
	add_child(_hbox)
	
	# Icon
	_icon_rect = TextureRect.new()
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.custom_minimum_size = Vector2(24, 24)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_setup_icon()
	_hbox.add_child(_icon_rect)
	
	# Content (Name + Path/Desc)
	_content_vbox = VBoxContainer.new()
	_content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_vbox.add_theme_constant_override("separation", 0)
	_hbox.add_child(_content_vbox)
	
	_name_lbl = Label.new()
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_lbl.add_theme_font_size_override("font_size", SpotlightTheme.FONT_SIZE_NORMAL)
	_name_lbl.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
	_content_vbox.add_child(_name_lbl)
	
	_setup_text_content()
		
	# Container Arrow / Tag
	if data.is_container:
		_arrow_icon = TextureRect.new()
		_arrow_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arrow_icon.texture = get_theme_icon("ArrowRight", "EditorIcons")
		_arrow_icon.modulate = Color(1, 1, 1, 0.5)
		_arrow_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_arrow_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hbox.add_child(_arrow_icon)
	else:
		_setup_tag()

func _setup_text_content():
	var title = data.file_name
	var desc = ""
	
	if data.type == SearchData.Type.COMMAND:
		title = data.file_name 
		desc = data.desc
		
		if data.command_name.contains("[") or data.command_name.contains("Requires:"):
			title = data.command_name
		
	elif data.type == SearchData.Type.ACTION:
		title = data.file_name
		desc = data.desc
		
	elif data.type == SearchData.Type.NODE:
		desc = data.desc # Relative path
		
	else:
		# Files
		if data.file_path.length() > 60:
			desc = "..." + data.file_path.right(60)
		else:
			desc = data.file_path
	
	_name_lbl.text = title
	
	if desc != "":
		_desc_lbl = Label.new()
		_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_desc_lbl.text = desc
		_desc_lbl.add_theme_font_size_override("font_size", 12)
		_desc_lbl.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
		_desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_content_vbox.add_child(_desc_lbl)

func _setup_icon():
	var theme = EditorInterface.get_editor_theme()
	var icon_tex = null
	
	if data.type == SearchData.Type.NODE:
		if data.icon_name != "" and theme.has_icon(data.icon_name, "EditorIcons"):
			icon_tex = theme.get_icon(data.icon_name, "EditorIcons")
		else:
			icon_tex = theme.get_icon("Node", "EditorIcons")
	else:
		var icon_name = SearchData.get_icon_name(data.type)
		if data.icon_name != "": icon_name = data.icon_name # Allow override
		if theme.has_icon(icon_name, "EditorIcons"):
			icon_tex = theme.get_icon(icon_name, "EditorIcons")
	
	if icon_tex:
		_icon_rect.texture = icon_tex
		_icon_rect.modulate = Color(1, 1, 1, 0.9)

func _setup_tag():
	var tag_text = ""
	var tag_color = Color(0.5, 0.5, 0.5, 0.2)
	
	match data.type:
		SearchData.Type.COMMAND:
			tag_text = "CMD"
			tag_color = Color(1, 0.8, 0.4, 0.2)
		SearchData.Type.ACTION:
			tag_text = "ACT"
			tag_color = Color(0.4, 0.8, 1, 0.2)
		SearchData.Type.CREATE_ACTION:
			tag_text = "NEW"
			tag_color = Color(0.4, 1, 0.6, 0.2)
		SearchData.Type.NODE:
			tag_text = "NODE"
			tag_color = Color(0.8, 0.4, 0.4, 0.2)
		SearchData.Type.PROPERTY:
			tag_text = "PROP"
			tag_color = Color(0.6, 0.6, 0.6, 0.2)
		SearchData.Type.METHOD:
			tag_text = "FUNC"
			tag_color = Color(0.4, 0.6, 0.9, 0.2)
			
	if tag_text != "":
		_tag_panel = PanelContainer.new()
		_tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = tag_color
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		_tag_panel.add_theme_stylebox_override("panel", style)
		
		_tag_lbl = Label.new()
		_tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tag_lbl.text = tag_text
		_tag_lbl.add_theme_font_size_override("font_size", 10)
		_tag_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		_tag_panel.add_child(_tag_lbl)
		
		# Align efficiently
		_tag_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hbox.add_child(_tag_panel)

func set_highlight(active: bool):
	is_selected = active
	_update_style()

func _update_style():
	add_theme_stylebox_override("panel", SpotlightTheme.get_item_stylebox(is_selected, is_hovered))
	
	if is_selected:
		_name_lbl.add_theme_color_override("font_color", SpotlightTheme.COL_ACCENT)
		if _desc_lbl: _desc_lbl.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
		if _arrow_icon: _arrow_icon.modulate = SpotlightTheme.COL_ACCENT
	else:
		_name_lbl.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_MAIN)
		if _desc_lbl: _desc_lbl.add_theme_color_override("font_color", SpotlightTheme.COL_TEXT_DIM)
		if _arrow_icon: _arrow_icon.modulate = Color(1, 1, 1, 0.5)

func _gui_input(event):
	if event is InputEventMouseMotion:
		if not is_hovered:
			is_hovered = true
			_update_style()
			
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Execute on release to allow Drag & Drop to work (which consumes the pressed event)
			if not event.pressed:
				item_pressed.emit(data)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_clicked.emit(data, get_screen_position() + event.position)

func _notification(what):
	if what == NOTIFICATION_MOUSE_EXIT:
		is_hovered = false
		_update_style()

func _get_drag_data(_pos):
	if data.type == SearchData.Type.COMMAND or data.type == SearchData.Type.CREATE_ACTION: return null
	if data.type == SearchData.Type.ACTION: return null
	
	var preview = HBoxContainer.new()
	preview.modulate.a = 0.8
	var icon = _icon_rect.duplicate()
	icon.custom_minimum_size = Vector2(32, 32)
	preview.add_child(icon)
	var lbl = Label.new()
	lbl.text = data.file_name
	preview.add_child(lbl)
	set_drag_preview(preview)

	if data.type == SearchData.Type.NODE:
		var root = EditorInterface.get_edited_scene_root()
		if root:
			var node = root.get_node_or_null(data.file_path)
			if node:
				return { "type": "nodes", "nodes": [node.get_path()] }
		return null

	if data.type == SearchData.Type.PROPERTY or data.type == SearchData.Type.METHOD:
		var prop_preview = HBoxContainer.new()
		var prop_lbl = Label.new()
		prop_lbl.text = data.file_name
		prop_preview.add_child(prop_lbl)
		set_drag_preview(prop_preview)
		
		return data.file_path

	return { "type": "files", "files": [data.file_path], "from": self }
