@tool
extends RefCounted
class_name SpotlightAction

## 定义底部按钮的行为。

var text: String
var shortcut_text: String
var callback: Callable

func _init(p_text: String, p_callback: Callable, p_shortcut: String = "") -> void:
	text = p_text
	callback = p_callback
	shortcut_text = p_shortcut
