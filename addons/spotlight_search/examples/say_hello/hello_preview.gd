@tool
extends Control

@onready var title_label: Label = $TitleLabel
@onready var input_edit: TextEdit = $InputEdit

func setup(item):
	if title_label:
		title_label.text = "Greeting: " + item.title
	
func _on_submit_pressed():
	if input_edit:
		var txt = input_edit.text
		if txt.is_empty(): txt = "Nothing..."
		print("[Spotlight Scene] User says: " + txt)
		input_edit.text = ""
