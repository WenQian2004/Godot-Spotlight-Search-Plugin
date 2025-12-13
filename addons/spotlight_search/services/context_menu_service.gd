@tool
extends RefCounted

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
const SearchLogic = preload("res://addons/spotlight_search/services/search_logic.gd")
const Config = preload("res://addons/spotlight_search/services/context_menu_config.gd")
const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")

var logic: SearchLogic

func _init(l: SearchLogic):
	logic = l

func get_menu_config(data: SearchData) -> Array:
	var menus = []
	if data.type == SearchData.Type.NODE:
		menus = Config.MENUS["node"].duplicate(true)
	elif data.type == SearchData.Type.SCRIPT:
		menus = Config.MENUS["script"].duplicate(true)
	elif data.type == SearchData.Type.COMMAND or data.type == SearchData.Type.CREATE_ACTION:
		return [] # No context menu for commands yet
	else:
		menus = Config.MENUS["default"].duplicate(true)
	
	# Translate menu labels
	for item in menus:
		if item.has("label"):
			item.label = _translate_label(item.id)
			
	return menus

func _translate_label(id: String) -> String:
	match id:
		Config.ID_COPY_PATH: return TranslationService.get_string("ctx_copy_path")
		Config.ID_COPY_NAME: return TranslationService.get_string("ctx_copy_name")
		Config.ID_SHOW_IN_FS: return TranslationService.get_string("ctx_show_in_fs")
		Config.ID_OPEN_FOLDER: return TranslationService.get_string("ctx_open_folder")
		Config.ID_OPEN_EXTERNAL: return TranslationService.get_string("ctx_open_external")
		Config.ID_TOGGLE_PIN: return TranslationService.get_string("ctx_pin") # Or Unpin, dynamic in window
		Config.ID_COPY_NODE_PATH: return TranslationService.get_string("ctx_copy_node_path")
		Config.ID_COPY_NODE_NAME: return TranslationService.get_string("ctx_copy_node_name")
		Config.ID_DELETE_FILE: return TranslationService.get_string("ctx_delete")
		Config.ID_DUPLICATE: return TranslationService.get_string("ctx_duplicate")
		_: return TranslationService.get_string("ctx_unknown")

func handle_action(id: String, data: SearchData):
	match id:
		Config.ID_COPY_PATH:
			DisplayServer.clipboard_set(data.file_path)
			print("[Spotlight] Copied path: ", data.file_path)
			
		Config.ID_COPY_NODE_PATH:
			var root = EditorInterface.get_edited_scene_root()
			if not root:
				print("[Spotlight] No edited scene root found.")
				return

			var node = root.get_node_or_null(data.file_path)
			if node:
				var path = str(root.get_path_to(node))
				var text = "$" + path
				if " " in path: text = '$"%s"' % path
				
				DisplayServer.clipboard_set(text)
				print("[Spotlight] Copied node path: ", text)
			else:
				print("[Spotlight] Node not found: ", data.file_path)
			
		Config.ID_COPY_NAME, Config.ID_COPY_NODE_NAME:
			DisplayServer.clipboard_set(data.file_name)
			print("[Spotlight] Copied name: ", data.file_name)

		Config.ID_SHOW_IN_FS:
			if data.type == SearchData.Type.NODE:
				_focus_in_scene_tree(data.file_path)
			else:
				EditorInterface.select_file(data.file_path)
				
		Config.ID_TOGGLE_PIN:
			logic.toggle_pin(data.file_path)
			
		Config.ID_OPEN_EXTERNAL:
			var global_path = ProjectSettings.globalize_path(data.file_path)
			OS.shell_open(global_path)
			print("[Spotlight] Opened in external app: ", global_path)
			
		Config.ID_OPEN_FOLDER:
			var dir_path = data.file_path.get_base_dir()
			var global_path = ProjectSettings.globalize_path(dir_path)
			OS.shell_open(global_path)
			print("[Spotlight] Opened folder: ", global_path)
			
		Config.ID_DELETE_FILE:
			var global_path = ProjectSettings.globalize_path(data.file_path)
			var err = OS.move_to_trash(global_path)
			if err == OK:
				print("[Spotlight] Moved to trash: ", data.file_path)
				# Trigger filesystem rescan
				EditorInterface.get_resource_filesystem().scan()
			else:
				push_warning("[Spotlight] Failed to delete: " + data.file_path)
				
		Config.ID_DUPLICATE:
			# Duplicate node in scene
			var root = EditorInterface.get_edited_scene_root()
			if root:
				var node = root.get_node_or_null(data.file_path)
				if node:
					var dup = node.duplicate()
					dup.name = node.name + "_copy"
					node.get_parent().add_child(dup)
					dup.owner = root
					EditorInterface.get_selection().clear()
					EditorInterface.get_selection().add_node(dup)
					print("[Spotlight] Duplicated node: ", dup.name)

func _focus_in_scene_tree(node_path: String):
	# Node path is likely absolute like "/root/Scene/Node"
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	var node = root.get_node_or_null(node_path)
	# If node_path is relative to root, try that too
	if not node and root.has_node(node_path):
		node = root.get_node(node_path)
		
	if node:
		var selection = EditorInterface.get_selection()
		selection.clear()
		selection.add_node(node)

		if node is Node3D:
			EditorInterface.set_main_screen_editor("3D")
		elif node is Control or node is Node2D:
			EditorInterface.set_main_screen_editor("2D")
