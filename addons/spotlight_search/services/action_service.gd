@tool
extends RefCounted

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
const SearchLogic = preload("res://addons/spotlight_search/services/search_logic.gd")
const ActionRegistry = preload("res://addons/spotlight_search/services/action_registry.gd")

var logic: SearchLogic

func _init(l: SearchLogic):
	logic = l
	ActionRegistry.register_builtins()

# Returns true if the window should be closed
func execute(data: SearchData, shift_pressed: bool = false) -> bool:
	match data.type:
		SearchData.Type.ACTION:
			return await _handle_action(data)
		SearchData.Type.CREATE_ACTION:
			# args[0] is path, args[1] is content hint (unused by registry currently)
			return await _create_file(data.args[0], data.args[1] if data.args.size() > 1 else "")
		SearchData.Type.FILE, SearchData.Type.SCRIPT, SearchData.Type.SCENE, SearchData.Type.RESOURCE, SearchData.Type.SHADER, SearchData.Type.IMAGE, SearchData.Type.AUDIO:
			return await _open_file(data, shift_pressed)
		SearchData.Type.NODE:
			await _focus_node(data)
			return true
	
	return false

func _handle_action(data: SearchData) -> bool:
	var action_id = data.file_path # For ACTION type, file_path stores the action_id
	var args = data.args
	
	if action_id == "open_settings":
		ActionRegistry.execute("open_settings")
		return true 
		
	await ActionRegistry.execute(action_id, args)
	return true

# --- Helper Functions ---

func _create_file(path: String, _content_hint: String) -> bool:
	await ActionRegistry.execute("create_file", [path])
	return true

func _open_file(data: SearchData, shift: bool) -> bool:
	# Record history
	logic.add_to_history(data.file_path)
	
	if data.type == SearchData.Type.SCRIPT:
		await ActionRegistry.execute("edit_resource", [data.file_path])
	elif data.type == SearchData.Type.SCENE:
		if shift:
			await ActionRegistry.execute("instantiate_scene", [data.file_path])
		else:
			await ActionRegistry.execute("open_scene", [data.file_path])
	else:
		await ActionRegistry.execute("select_file", [data.file_path])
	return true

func _focus_node(data: SearchData) -> void:
	await ActionRegistry.execute("jump_to_node", [data.file_path])
