@tool
extends RefCounted
class_name SpotlightFavoritesManager

const SAVE_PATH = "user://spotlight_favorites.json"

# Static cache for favorites
# Structure: { "unique_id": timestamp }
static var _favorites_cache = null

# --- API ---

static func toggle_favorite(item_id: String):
	_ensure_loaded()
	if is_favorite(item_id):
		_favorites_cache.erase(item_id)
	else:
		_favorites_cache[item_id] = Time.get_unix_time_from_system()
	_save_data()

static func is_favorite(item_id: String) -> bool:
	_ensure_loaded()
	return _favorites_cache.has(item_id)

static func get_all_favorites() -> Array:
	_ensure_loaded()
	return _favorites_cache.keys()

# --- Internal ---

static func _ensure_loaded():
	if _favorites_cache == null:
		_load_data()

static func _save_data():
	if _favorites_cache == null: return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_favorites_cache))

static func _load_data():
	_favorites_cache = {}
	
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK:
			var data = json.get_data()
			if data is Dictionary:
				_favorites_cache = data
