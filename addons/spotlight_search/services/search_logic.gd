@tool
extends RefCounted

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
const ConfigManager = preload("res://addons/spotlight_search/managers/config_manager.gd")

const HISTORY_FILE = "res://.godot/spotlight_history.json"
const MAX_HISTORY = 20
const TRACK_GROUP = "spotlight_tracked"

var all_files: Array[SearchData] = []
var search_history: Array[String] = []
var pinned_items: Array[String] = []

var _scan_thread: Thread
var _dirty: bool = false

signal scan_completed

func _init():
	_scan_thread = Thread.new()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _scan_thread.is_started():
			_scan_thread.wait_to_finish()

func search_nodes(query: String) -> Array[SearchData]:
	var results: Array[SearchData] = []
	var root = EditorInterface.get_edited_scene_root()
	
	if not root: 
		return results
	
	var tracked_nodes = root.get_tree().get_nodes_in_group(TRACK_GROUP)
	var query_lower = query.to_lower().strip_edges()
	
	for node in tracked_nodes:
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
			
		if node != root and not root.is_ancestor_of(node):
			continue
			
		var score = 0
		if query_lower == "":
			score = 100
		else:
			score = calculate_fuzzy_score(query_lower, node.name.to_lower())
		
		if score > 0:
			var item = SearchData.new()
			item.file_name = node.name
			item.file_path = str(node.get_path())
			item.type = SearchData.Type.NODE
			item.score = score
			
			var rel_path = str(root.get_path_to(node))
			if " " in rel_path: rel_path = '"%s"' % rel_path
			item.desc = "$" + rel_path
			
			item.icon_name = node.get_class()
			results.append(item)
			
	return results

func scan_filesystem():
	if _scan_thread.is_started():
		if _scan_thread.is_alive():
			_dirty = true
			return
		else:
			_scan_thread.wait_to_finish()
	
	var fs = EditorInterface.get_resource_filesystem()
	var root = fs.get_filesystem()
	if root:
		var excludes = ConfigManager.get_exclude_patterns()
		_scan_thread.start(_thread_scan.bind(root, excludes))

func _thread_scan(root: EditorFileSystemDirectory, excludes: PackedStringArray):
	var new_files: Array[SearchData] = []
	_recursive_scan(root, new_files, excludes)
	
	call_deferred("_on_scan_completed", new_files)

func _on_scan_completed(new_files: Array[SearchData]):
	if _scan_thread.is_started():
		_scan_thread.wait_to_finish()
		
	all_files = new_files
	emit_signal("scan_completed")
	
	if _dirty:
		scan_filesystem()

func _recursive_scan(dir: EditorFileSystemDirectory, target_array: Array[SearchData], excludes: PackedStringArray):
	if not is_instance_valid(dir): return
	
	var dir_path = dir.get_path()
	for pattern in excludes:
		if pattern in dir_path: return
		
	for i in dir.get_file_count():
		var fname = dir.get_file(i)
		if fname.begins_with("."): continue
		
		var item = SearchData.new()
		item.file_name = fname
		item.file_path = dir.get_file_path(i)
		if not FileAccess.file_exists(item.file_path): continue
		
		item.type = SearchData.get_type_from_path(item.file_path)
		target_array.append(item)
		
	for i in dir.get_subdir_count():
		_recursive_scan(dir.get_subdir(i), target_array, excludes)

func load_history():
	if FileAccess.file_exists(HISTORY_FILE):
		var file = FileAccess.open(HISTORY_FILE, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary:
				search_history.assign(data.get("history", []))
				pinned_items.assign(data.get("pinned", []))

func save_history():
	var file = FileAccess.open(HISTORY_FILE, FileAccess.WRITE)
	if file:
		var data = { "history": search_history, "pinned": pinned_items }
		file.store_string(JSON.stringify(data))

func add_to_history(path: String):
	if path in search_history: search_history.erase(path)
	search_history.push_front(path)
	if search_history.size() > MAX_HISTORY: search_history.resize(MAX_HISTORY)
	save_history()

func toggle_pin(path: String):
	if path in pinned_items: pinned_items.erase(path)
	else: pinned_items.append(path)
	save_history()

func is_pinned(path: String) -> bool:
	return path in pinned_items

func calculate_fuzzy_score(query: String, target: String) -> int:
	if query == "": return 0
	if query == target: return 100
	
	var q_len = query.length()
	var t_len = target.length()
	
	if q_len > t_len: return 0
	
	var score = 0
	var q_idx = 0
	var t_idx = 0
	var consec = 0
	
	if target.begins_with(query): score += 30
	
	while q_idx < q_len and t_idx < t_len:
		var q_char = query[q_idx]
		var t_char = target[t_idx]
		
		if q_char == t_char:
			score += 10
			score += consec * 5
			consec += 1
			q_idx += 1
		else:
			consec = 0
			score -= 1
		
		t_idx += 1
	
	if q_idx < q_len: return 0
	
	var len_diff = t_len - q_len
	score -= int(len_diff * 0.5)
	
	return max(1, score)
