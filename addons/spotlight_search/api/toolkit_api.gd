@tool
extends RefCounted

const ActionRegistry = preload("res://addons/spotlight_search/services/action_registry.gd")

# ToolkitAPI
# Public API for Spotlight Search extensions

# Register a custom action
# @param action_id: Unique identifier for the action
# @param callable: Function to execute (receives Array of args)
static func register_action(action_id: String, callable: Callable) -> void:
	ActionRegistry.register_action(action_id, callable)

# Show a toast notification
# @param message: Text to display
# @param type: "info", "success", "warning", "error"
static func show_toast(message: String, type: String = "info") -> void:
	# Use the global ToastManager if available
	# For now, print to console as fallback
	var prefix = ""
	match type:
		"success": prefix = "✅ "
		"warning": prefix = "⚠️ "
		"error": prefix = "❌ "
		_: prefix = "ℹ️ "
		
	print("[Spotlight] %s%s" % [prefix, message])
	
	# Dispatch to actual UI if possible
	var main_window = _get_spotlight_window()
	if main_window and main_window.has_method("show_toast"):
		main_window.show_toast(message, type)

static func _get_spotlight_window() -> Node:
	# Helper to find the window instance in the editor tree
	var base = EditorInterface.get_base_control()
	
	return base.find_child("SpotlightWindow", true, false)
