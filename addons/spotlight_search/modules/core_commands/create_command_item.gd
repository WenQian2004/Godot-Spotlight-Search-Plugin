@tool
extends SpotlightResultItem
class_name CreateCommandResult

var panel_script: Script

func _init():
	title = "New Resource..."
	description = "Create a new script, scene, or folder."
	icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	type = ItemType.LEAF # Leaf, because we don't want to drill down into a list
	
	panel_script = load("res://addons/spotlight_search/ui/components/create_resource/create_resource_panel.gd")

func get_preview_type() -> PreviewType:
	return PreviewType.CUSTOM

func create_custom_preview() -> Control:
	if panel_script:
		return panel_script.new()
	return null

func get_unique_id() -> String:
	return "cmd.new.custom"

func execute():
	pass
