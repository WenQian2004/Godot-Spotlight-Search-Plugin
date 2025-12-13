extends EditorInspectorPlugin

const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")

const TRACK_GROUP = "spotlight_tracked"

func _can_handle(object):
	return object is Node

func _parse_begin(object):
	if not object is Node: return
	var node = object as Node
	
	var btn = Button.new()
	var is_tracked = node.is_in_group(TRACK_GROUP)
	
	_update_btn_style(btn, is_tracked)
	
	btn.pressed.connect(func():
		if node.is_in_group(TRACK_GROUP):
			node.remove_from_group(TRACK_GROUP)
			_update_btn_style(btn, false)
			print("Spotlight: Untracked '" + node.name + "'")
		else:
			node.add_to_group(TRACK_GROUP, true)
			_update_btn_style(btn, true)
			print("Spotlight: Tracked '" + node.name + "'")
	)
	
	add_custom_control(btn)

func _update_btn_style(btn: Button, is_tracked: bool):
	var theme = EditorInterface.get_editor_theme()
	if is_tracked:
		btn.text = TranslationService.get_string("tracker_remove")
		btn.icon = theme.get_icon("Favorites", "EditorIcons")
		btn.modulate = Color(1, 0.5, 0.5)
	else:
		btn.text = TranslationService.get_string("tracker_add")
		btn.icon = theme.get_icon("Favorites", "EditorIcons")
		btn.modulate = Color(0.5, 1, 0.5)
