@tool
extends RefCounted

## Manages command history with persistence across sessions

const ConfigManager = preload("res://addons/spotlight_search/managers/config_manager.gd")

const SETTING_HISTORY = "addons/spotlight_search/command_history"
const SETTING_FAVORITES = "addons/spotlight_search/favorites"
const MAX_HISTORY = 20

static var _history: Array[String] = []
static var _favorites: Array[String] = []
static var _initialized = false

static func initialize():
	if _initialized: return
	_initialized = true
	
	# Load from ProjectSettings
	if ProjectSettings.has_setting(SETTING_HISTORY):
		var saved = ProjectSettings.get_setting(SETTING_HISTORY)
		if saved is Array:
			_history.assign(saved)
	
	if ProjectSettings.has_setting(SETTING_FAVORITES):
		var saved = ProjectSettings.get_setting(SETTING_FAVORITES)
		if saved is Array:
			_favorites.assign(saved)

static func add_to_history(command: String):
	if command.strip_edges().is_empty(): return
	if not command.begins_with("-"): return  # Only save commands
	
	# Remove if exists, then add to front
	if command in _history:
		_history.erase(command)
	_history.insert(0, command)
	
	# Limit size
	while _history.size() > MAX_HISTORY:
		_history.pop_back()
	
	_save()

static func get_history() -> Array[String]:
	initialize()
	return _history.duplicate()

static func get_recent(count: int = 10) -> Array[String]:
	initialize()
	var result: Array[String] = []
	for i in mini(count, _history.size()):
		result.append(_history[i])
	return result

static func clear_history():
	_history.clear()
	_save()

# Favorites
static func add_favorite(command: String):
	if command.strip_edges().is_empty(): return
	if command in _favorites: return
	_favorites.append(command)
	_save()

static func remove_favorite(command: String):
	_favorites.erase(command)
	_save()

static func is_favorite(command: String) -> bool:
	initialize()
	return command in _favorites

static func get_favorites() -> Array[String]:
	initialize()
	return _favorites.duplicate()

static func toggle_favorite(command: String) -> bool:
	initialize()
	if command in _favorites:
		_favorites.erase(command)
		_save()
		return false
	else:
		_favorites.append(command)
		_save()
		return true

static func _save():
	ProjectSettings.set_setting(SETTING_HISTORY, _history)
	ProjectSettings.set_setting(SETTING_FAVORITES, _favorites)
	ProjectSettings.save()
