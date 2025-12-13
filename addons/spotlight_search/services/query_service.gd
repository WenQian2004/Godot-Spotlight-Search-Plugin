@tool
extends RefCounted

const SearchData = preload("res://addons/spotlight_search/data/search_data.gd")
const SearchLogic = preload("res://addons/spotlight_search/services/search_logic.gd")
const CommandManager = preload("res://addons/spotlight_search/managers/command_manager.gd")
const ConfigManager = preload("res://addons/spotlight_search/managers/config_manager.gd")
const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")

var logic: SearchLogic

func _init(l: SearchLogic):
	logic = l

func process_query(query: String) -> Array[SearchData]:
	# Use left-only stripping to preserve trailing spaces for command parsing
	var q = query.strip_edges(true, false)
	
	# 0. Empty State
	if q == "":
		return _get_zero_query_results()
	
	# 1. Recursive Command Parsing
	if q.begins_with("-"):
		var cmd_result = _try_parse_command(q)
		if cmd_result != null:
			var typed_result: Array[SearchData] = []
			typed_result.assign(cmd_result)
			return typed_result

	return _get_search_results(query)

func _try_parse_command(query: String) -> Variant:
	var tokens = query.split(" ", false)
	if tokens.is_empty(): return [] as Array[SearchData]
	
	var current_scope = CommandManager.COMMANDS
	var last_scope = CommandManager.COMMANDS
	var matched_depth = 0
	var current_config = null
	
	for i in range(tokens.size()):
		var token = tokens[i]
		if current_scope.has(token):
			last_scope = current_scope
			current_config = current_scope[token]
			matched_depth = i + 1
			
			if current_config.get("type") == "container":
				current_scope = current_config.get("children", {})
			else:
				# Action reached, stop matching commands
				break
		else:
			# Token not found in current scope, stop matching
			break
			
	# 2. Handle results based on match depth
	
	# Case A: No valid command matched at all
	if matched_depth == 0:
		if tokens.size() == 1 and not query.ends_with(" "):
			return _get_command_suggestions(tokens[0])
		return null
		
	# Case B: Matched a chain
	var last_matched_token = tokens[matched_depth - 1]
	
	# Reconstruct the full path of the command for display/navigation
	var full_cmd_path = ""
	for i in range(matched_depth):
		if i > 0: full_cmd_path += " "
		full_cmd_path += tokens[i]
		
	var parent_cmd_path = ""
	for i in range(matched_depth - 1):
		if i > 0: parent_cmd_path += " "
		parent_cmd_path += tokens[i]
	
	# If the last matched item is a CONTAINER
	if current_config.get("type") == "container":
		# 1. Exact match of container chain (e.g. "-assets -addons")
		if tokens.size() == matched_depth:
			if query.ends_with(" "):
				# User typed space, show children
				return _get_sub_commands_from_map(full_cmd_path, current_scope, "")
			else:
				return _get_sub_commands_from_map(parent_cmd_path, last_scope, last_matched_token)
				
		# 2. Partial match of a child (e.g. "-assets -addons -sc")
		elif tokens.size() == matched_depth + 1:
			var prefix = tokens[matched_depth]
			if not query.ends_with(" "):
				return _get_sub_commands_from_map(full_cmd_path, current_scope, prefix)
		
		return [] as Array[SearchData]

	# If the last matched item is an ACTION (or search_nodes)
	elif current_config.get("type") == "action" or current_config.get("type") == "create_file" or current_config.get("handler") == "search_nodes" or current_config.get("type") == "filter" or current_config.get("type") == "custom":
		# Calculate arguments
		var arg_start = 0
		var search_start = 0
		for i in range(matched_depth):
			var t = tokens[i]
			var p = query.find(t, search_start)
			if p != -1:
				search_start = p + t.length()
		
		var arg_str = ""
		if search_start < query.length():
			arg_str = query.substr(search_start).strip_edges()
			
		if current_config.get("handler") == "search_nodes":
			return _get_node_results(arg_str)
		elif current_config.get("handler") == "list_engine_nodes":
			return _get_engine_node_results(arg_str, full_cmd_path)
		elif current_config.get("handler") == "list_class_members":
			return _get_class_member_results(arg_str, full_cmd_path)
		elif current_config.get("handler") == "color_picker":
			return _get_color_results(arg_str)
		elif current_config.get("type") == "filter":
			return _get_search_results(arg_str, current_config.get("target_type", -1))
		else:
			# Pass full command path (e.g. "-test1 -res") as name_hint
			return _handle_leaf_command(current_config, arg_str, full_cmd_path)
			
	return [] as Array[SearchData]

func _get_command_suggestions(prefix: String) -> Array[SearchData]:
	return _get_sub_commands_from_map("", CommandManager.COMMANDS, prefix)

func _get_sub_commands(parent_cmd: String, parent_config: Dictionary, prefix: String) -> Array[SearchData]:
	return _get_sub_commands_from_map(parent_cmd, parent_config.get("children", {}), prefix)

func _get_sub_commands_from_map(parent_cmd: String, children: Dictionary, prefix: String) -> Array[SearchData]:
	var results: Array[SearchData] = []
	
	for key in children:
		# Support matching "script" against "-script"
		var match_key = key
		if prefix != "" and not prefix.begins_with("-") and key.begins_with("-"):
			match_key = key.substr(1)
			
		if prefix == "" or key.begins_with(prefix) or match_key.begins_with(prefix):
			var conf = children[key]
			var item = SearchData.new()
			item.file_name = key 
			item.desc = conf.get("desc", "")
			item.command_name = conf.get("name", item.desc)
			item.icon_name = conf.get("icon", "Search")
			
			if conf.get("type") == "container" or conf.get("type") == "filter" or conf.get("type") == "custom" or conf.get("handler") == "search_nodes" or conf.get("handler") == "list_engine_nodes" or conf.get("handler") == "list_class_members":
				item.type = SearchData.Type.COMMAND
				if conf.get("type") == "container":
					item.is_container = true
				
				if parent_cmd.is_empty():
					item.file_path = key
				else:
					item.file_path = parent_cmd + " " + key
			else:
				# Leaf action: execute directly
				var handler_id = conf.get("handler", "")
				if handler_id == "":
					push_warning("[Spotlight] Command '%s' has no action_id/handler defined." % key)
					continue
					
				item.type = SearchData.Type.ACTION
				
				if parent_cmd.is_empty():
					item.file_name = key
				else:
					item.file_name = parent_cmd + " " + key
					
				item.file_path = handler_id
				item.args = conf.get("args", [])
			
			results.append(item)
			
	# Sort results: Built-in filters first
	var priority = ["-gd", "-sc", "-img", "-res", "-track", "-node", "-class", "-new", "-config"]
	results.sort_custom(func(a, b):
		var a_key = a.file_name
		var b_key = b.file_name
		var a_idx = priority.find(a_key)
		var b_idx = priority.find(b_key)
		
		if a_idx != -1 and b_idx != -1: return a_idx < b_idx
		if a_idx != -1: return true
		if b_idx != -1: return false
		
		return a_key < b_key
	)
			
	return results

func _handle_leaf_command(config: Dictionary, arg: String, name_hint: String = "Action") -> Array[SearchData]:
	var handler = config.get("handler")
	var ext = config.get("extension", "gd")
	
	# Handle Parameterized Commands
	if config.has("args_def"):
		var args_def = config["args_def"]
		var parsed_args = _parse_arguments(arg)
		var validation = _validate_arguments(parsed_args, args_def)
		
		var item = SearchData.new()
		item.icon_name = config.get("icon", "Search")
		
		if validation.valid or parsed_args.is_empty():
			if handler == null or handler == "":
				item.type = SearchData.Type.COMMAND
				item.file_name = name_hint
				item.file_path = name_hint
				item.desc = TranslationService.get_string("err_missing_action")
				item.command_name = name_hint + " [Config Error]"
				return [item]

			item.type = SearchData.Type.ACTION
			item.file_name = name_hint
			item.file_path = handler
			item.args = parsed_args
			item.desc = config.get("desc", "")
			item.command_name = name_hint + " " + _format_args_display(parsed_args)
		else:
			# Not valid and not empty -> Invalid input -> Show hint
			item.type = SearchData.Type.COMMAND
			item.file_name = name_hint
			# file_path is used for autocomplete text in COMMAND mode
			item.file_path = name_hint 
			item.desc = TranslationService.get_string("cmd_requires") + validation.hint
			item.command_name = name_hint + " " + validation.display_hint
			item.score = 1000 # Keep at top
			
		return [item]
	
	if handler == "create_file":
		if arg == "": 
			var item = SearchData.new()
			item.type = SearchData.Type.COMMAND
			item.file_name = config.get("keyword", "") # e.g. -script
			# Construct full suggestion
			var full_name = name_hint if name_hint != "" else config.get("keyword", "")
			item.file_path = full_name # Used for autocomplete text
			
			item.desc = TranslationService.get_string("cmd_enter_filename")
			item.command_name = full_name + " [Name]"
			item.icon_name = config.get("icon", "Script")
			item.score = 2000
			return [item]
			
		return _get_create_file_option(arg, ext, config.get("desc"), name_hint)
	
	if handler == "open_settings":
		var item = SearchData.new()
		item.file_name = TranslationService.get_string("cmd_manual_open_settings")
		item.type = SearchData.Type.ACTION
		item.desc = TranslationService.get_string("cmd_manual_open_settings_desc")
		item.file_path = "open_settings" # Special ID for action service
		return [item]
		
	if handler and handler != "search_nodes":
		var item = SearchData.new()
		item.file_name = name_hint
		item.type = SearchData.Type.ACTION
		item.desc = config.get("desc", "")
		item.file_path = handler
		item.icon_name = config.get("icon", "Search")
		item.args = config.get("args", [])
		return [item]
		
	return [] as Array[SearchData]

func _get_create_file_option(name: String, extension: String, desc_prefix: String, command_path: String) -> Array[SearchData]:
	var base_dir = "res://"
	
	# Determine context directory from Editor selection
	var paths = EditorInterface.get_selected_paths()
	if not paths.is_empty():
		var p = paths[0]
		# If it's a file, get its directory. If directory, use it.
		if FileAccess.file_exists(p):
			base_dir = p.get_base_dir()
		elif DirAccess.dir_exists_absolute(p):
			base_dir = p
	
	if not base_dir.ends_with("/"): base_dir += "/"
	
	var item = SearchData.new()
	var filename = name
	if not filename.ends_with("." + extension):
		filename += "." + extension
		
	item.file_name = TranslationService.get_string("cmd_create_prefix") + filename
	item.type = SearchData.Type.ACTION # Executable
	item.desc = desc_prefix + TranslationService.get_string("cmd_create_in") + base_dir
	item.file_path = "create_file"
	item.args = [base_dir + filename, "class_name " + name.capitalize().replace(" ", "")]
	item.icon_name = "Script" # Could rely on extension, but generic is fine or passed in config
	item.command_name = command_path + " " + name
	
	return [item]

func _get_node_results(arg: String) -> Array[SearchData]:
	# Allow empty arg to show all tracked nodes (handled by logic.search_nodes)
	return logic.search_nodes(arg)

func _get_engine_node_results(arg: String, parent_cmd: String) -> Array[SearchData]:
	var results: Array[SearchData] = []
	var parts = arg.split(" ", false)
	
	# Case 1: No args or just partial class name -> List Classes
	# Case 2: "ClassName" (Exact match) -> List Properties
	# Case 3: "ClassName partial_prop" -> List Properties filtered
	
	var target_class = ""
	var prop_filter = ""
	
	if parts.size() > 0:
		var p0 = parts[0]
		if ClassDB.class_exists(p0) and ClassDB.is_parent_class(p0, "Node"):
			target_class = p0
			if parts.size() > 1:
				prop_filter = parts[1]
	
	if target_class != "":
		# --- List Properties of Class with Hierarchy ---
		
		# Show class hierarchy info (only if no filter)
		if prop_filter == "":
			# Parent class (must also be Node)
			var parent = ClassDB.get_parent_class(target_class)
			if parent != "" and ClassDB.is_parent_class(parent, "Node"):
				var parent_item = SearchData.new()
				parent_item.type = SearchData.Type.COMMAND
				parent_item.file_name = "↑ " + parent
				parent_item.file_path = parent_cmd + " " + parent
				parent_item.desc = "Parent Node"
				parent_item.icon_name = parent
				parent_item.is_container = true
				parent_item.command_name = parent
				parent_item.score = 10000
				results.append(parent_item)
			
			# Child classes (limit to first 5, only Node types)
			var children = ClassDB.get_inheriters_from_class(target_class)
			var child_count = 0
			for child in children:
				if child.begins_with("_"): continue
				if not ClassDB.is_parent_class(child, "Node"): continue
				if child_count >= 5: break
				var child_item = SearchData.new()
				child_item.type = SearchData.Type.COMMAND
				child_item.file_name = "↓ " + child
				child_item.file_path = parent_cmd + " " + child
				child_item.desc = "Child Node (%d total)" % children.size() if child_count == 0 else "Child Node"
				child_item.icon_name = child
				child_item.is_container = true
				child_item.command_name = child
				child_item.score = 9000 - child_count
				results.append(child_item)
				child_count += 1
		
		# Properties
		var props = ClassDB.class_get_property_list(target_class)
		for p in props:
			
			var usage = p["usage"]
			if usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_SUBGROUP or usage & PROPERTY_USAGE_CATEGORY:
				continue
				
			if not (usage & PROPERTY_USAGE_EDITOR):
				continue
				
			var p_name = p["name"]
			if prop_filter != "" and not p_name.containsn(prop_filter):
				continue
				
			var item = SearchData.new()
			item.type = SearchData.Type.PROPERTY
			item.file_name = p_name
			item.file_path = p_name # The text to insert
			item.desc = "%s (%s)" % [target_class, _type_to_string(p["type"])]
			item.icon_name = "MemberProperty"
			item.command_name = p_name
			
			# Score based on match
			item.score = 100
			if p_name.begins_with(prop_filter): item.score += 50
			
			results.append(item)
			
		results.sort_custom(func(a, b): return a.score > b.score)
		
	else:
		
		var class_list = ClassDB.get_class_list()
		var arg_lower = arg.to_lower()
		
		for c_name in class_list:
			if not ClassDB.is_parent_class(c_name, "Node"): continue
			if c_name.begins_with("_"): continue # Skip internal classes
			
			if arg != "" and not c_name.to_lower().contains(arg_lower):
				continue
				
			var item = SearchData.new()
			item.type = SearchData.Type.COMMAND
			
			item.file_name = c_name
			item.file_path = parent_cmd + " " + c_name
			item.desc = "Engine Class"
			item.icon_name = c_name # Standard class icons work
			item.is_container = true # Shows arrow, implies drilling down
			item.command_name = c_name
			
			# Score
			var score = 0
			if c_name.to_lower().begins_with(arg_lower): score += 100
			elif c_name.to_lower().contains(arg_lower): score += 50
			
			# Prioritize exact match length
			score -= c_name.length() 
			
			item.score = score
			results.append(item)
		
		results.sort_custom(func(a, b): return a.score > b.score)
		results = results.slice(0, 50) # Limit results
		
	return results
	
func _type_to_string(type: int) -> String:
	match type:
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_COLOR: return "Color"
		TYPE_OBJECT: return "Object"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		_: return "Variant"

func _get_class_member_results(arg: String, parent_cmd: String) -> Array[SearchData]:
	var results: Array[SearchData] = []
	var parts = arg.split(" ", false)
	
	# Case 1: No args -> List ALL classes
	# Case 2: "ClassName" -> List Methods + Properties
	# Case 3: "ClassName filter" -> Filter members
	
	var target_class = ""
	var member_filter = ""
	
	if parts.size() > 0:
		var p0 = parts[0]
		if ClassDB.class_exists(p0):
			target_class = p0
			if parts.size() > 1:
				member_filter = parts[1]
	
	if target_class != "":
		# --- List Methods AND Properties of Class ---
		var filter_lower = member_filter.to_lower()
		
		# Show class hierarchy info (only if no filter)
		if member_filter == "":
			# Parent class
			var parent = ClassDB.get_parent_class(target_class)
			if parent != "":
				var parent_item = SearchData.new()
				parent_item.type = SearchData.Type.COMMAND
				parent_item.file_name = "↑ " + parent
				parent_item.file_path = parent_cmd + " " + parent
				parent_item.desc = "Parent Class"
				parent_item.icon_name = parent
				parent_item.is_container = true
				parent_item.command_name = parent
				parent_item.score = 10000
				results.append(parent_item)
			
			# Child classes (limit to first 5)
			var children = ClassDB.get_inheriters_from_class(target_class)
			var child_count = 0
			for child in children:
				if child.begins_with("_"): continue
				if child_count >= 5: break
				var child_item = SearchData.new()
				child_item.type = SearchData.Type.COMMAND
				child_item.file_name = "↓ " + child
				child_item.file_path = parent_cmd + " " + child
				child_item.desc = "Child Class (%d total)" % children.size() if child_count == 0 else "Child Class"
				child_item.icon_name = child
				child_item.is_container = true
				child_item.command_name = child
				child_item.score = 9000 - child_count
				results.append(child_item)
				child_count += 1
		
		# Properties
		var props = ClassDB.class_get_property_list(target_class)
		for p in props:
			var usage = p["usage"]
			if usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_SUBGROUP or usage & PROPERTY_USAGE_CATEGORY:
				continue
			if not (usage & PROPERTY_USAGE_EDITOR):
				continue
				
			var p_name = p["name"]
			if member_filter != "" and not p_name.to_lower().contains(filter_lower):
				continue
				
			var item = SearchData.new()
			item.type = SearchData.Type.PROPERTY
			item.file_name = p_name
			item.file_path = p_name # Drag text
			item.desc = "Property (%s)" % _type_to_string(p["type"])
			item.icon_name = "MemberProperty"
			item.command_name = p_name
			item.score = 100
			if p_name.to_lower().begins_with(filter_lower): item.score += 50
			results.append(item)
		
		# Methods
		var methods = ClassDB.class_get_method_list(target_class)
		for m in methods:
			var m_name = m["name"]
			if m_name.begins_with("_"): continue # Skip private/virtual
			if member_filter != "" and not m_name.to_lower().contains(filter_lower):
				continue
			
			# Build signature
			var args_str = ""
			var m_args = m.get("args", [])
			var arg_names = []
			for a in m_args:
				arg_names.append(a["name"])
			args_str = ", ".join(arg_names)
			
			var item = SearchData.new()
			item.type = SearchData.Type.METHOD
			item.file_name = m_name + "()"
			item.file_path = m_name + "(" + args_str + ")" # Drag text with args
			item.desc = "Method → " + _type_to_string(m.get("return", {}).get("type", 0))
			item.icon_name = "MemberMethod"
			item.command_name = m_name
			item.score = 80
			if m_name.to_lower().begins_with(filter_lower): item.score += 50
			results.append(item)
			
		results.sort_custom(func(a, b): return a.score > b.score)
		results = results.slice(0, 100)
		
	else:
		# --- List ALL Classes ---
		var class_list = ClassDB.get_class_list()
		var arg_lower = arg.to_lower()
		
		for c_name in class_list:
			if c_name.begins_with("_"): continue # Skip internal
			
			if arg != "" and not c_name.to_lower().contains(arg_lower):
				continue
				
			var item = SearchData.new()
			item.type = SearchData.Type.COMMAND
			item.file_name = c_name
			item.file_path = parent_cmd + " " + c_name
			item.desc = "Engine Class"
			item.icon_name = c_name
			item.is_container = true
			item.command_name = c_name
			
			var score = 0
			if c_name.to_lower().begins_with(arg_lower): score += 100
			elif c_name.to_lower().contains(arg_lower): score += 50
			score -= c_name.length()
			
			item.score = score
			results.append(item)
		
		results.sort_custom(func(a, b): return a.score > b.score)
		results = results.slice(0, 50)
		
	return results

func _get_search_results(query: String, filter_type: int = -1) -> Array[SearchData]:
	var results: Array[SearchData] = []
	var all_files = logic.all_files
	
	var q_lower = query.to_lower()
	var is_empty = query.is_empty()
	
	for item in all_files:
		if filter_type != -1 and item.type != filter_type: continue
		
		var score = 0
		if is_empty:
			score = 1
		else:
			score = logic.calculate_fuzzy_score(q_lower, item.file_name.to_lower())
			
		if score > 0:
			item.score = score
			results.append(item)
			
	results.sort_custom(func(a, b): return a.score > b.score)
	return results.slice(0, ConfigManager.get_max_results())

func _parse_arguments(arg_str: String) -> Array:
	var args = []
	var current = ""
	var in_quote = false
	
	for i in range(arg_str.length()):
		var c = arg_str[i]
		if c == '"':
			in_quote = not in_quote
			current += c
		elif c == ',' and not in_quote:
			args.append(current.strip_edges())
			current = ""
		else:
			current += c
			
	if not current.strip_edges().is_empty() or not args.is_empty():
		var last = current.strip_edges()
		if not last.is_empty() or in_quote:
			args.append(last)
		
	return args

func _validate_arguments(parsed_args: Array, args_def: Array) -> Dictionary:
	var result = {
		"valid": false,
		"error": "",
		"hint": "",
		"display_hint": ""
	}
	
	# Build display hint
	var hint_parts = []
	for i in range(args_def.size()):
		var def = args_def[i]
		if i < parsed_args.size():
			hint_parts.append(parsed_args[i])
		else:
			hint_parts.append("[%s]" % def.get("name", "arg%d" % i))
	result.display_hint = " ".join(hint_parts)
	
	if parsed_args.size() < args_def.size():
		var missing_idx = parsed_args.size()
		var missing_def = args_def[missing_idx]
		result.error = "Missing argument: %s" % missing_def.get("name", "arg")
		result.hint = "Enter %s (%s)" % [missing_def.get("name", "arg"), missing_def.get("type", "string")]
		return result
		
	# Type validation (Basic)
	for i in range(args_def.size()):
		var def = args_def[i]
		var val = parsed_args[i]
		var type = def.get("type", "string")
		
		if type == "int" and not val.is_valid_int():
			result.error = "Argument %d must be an integer" % (i+1)
			result.hint = "Fix argument %d" % (i+1)
			return result
		elif type == "float" and not val.is_valid_float():
			result.error = "Argument %d must be a number" % (i+1)
			result.hint = "Fix argument %d" % (i+1)
			return result
			
	result.valid = true
	return result

func _format_args_display(args: Array) -> String:
	return " ".join(args)

func _get_zero_query_results() -> Array[SearchData]:
	var results: Array[SearchData] = []
	var added_paths = {}
	var max_results = ConfigManager.get_max_results()
	
	# 1. Add pinned items (filter out deleted files)
	for path in logic.pinned_items:
		if not FileAccess.file_exists(path): continue
		var item = SearchData.new()
		item.file_path = path
		item.file_name = path.get_file()
		item.type = SearchData.get_type_from_path(path)
		item.desc = "Pinned"
		item.score = 1000
		results.append(item)
		added_paths[path] = true
		
	# 2. Add recent history (filter out deleted files)
	for path in logic.search_history:
		if path in added_paths: continue
		if not FileAccess.file_exists(path): continue
		var item = SearchData.new()
		item.file_path = path
		item.file_name = path.get_file()
		item.type = SearchData.get_type_from_path(path)
		item.desc = "Recent"
		item.score = 500
		results.append(item)
		added_paths[path] = true
		if results.size() >= max_results: return results
		
	# 3. Fill with recommended items (Scenes & Scripts)
	if results.size() < max_results:
		for item in logic.all_files:
			if results.size() >= max_results: break
			if item.file_path in added_paths: continue
			
			if item.type == SearchData.Type.SCENE or item.type == SearchData.Type.SCRIPT:
				var new_item = SearchData.new()
				new_item.file_name = item.file_name
				new_item.file_path = item.file_path
				new_item.type = item.type
				new_item.desc = item.file_path.get_base_dir()
				new_item.score = 100
				results.append(new_item)
				added_paths[item.file_path] = true
	
	# 4. Fill with remaining items if needed
	if results.size() < max_results:
		for item in logic.all_files:
			if results.size() >= max_results: break
			if item.file_path in added_paths: continue
			
			var new_item = SearchData.new()
			new_item.file_name = item.file_name
			new_item.file_path = item.file_path
			new_item.type = item.type
			new_item.desc = item.file_path.get_base_dir()
			new_item.score = 50
			results.append(new_item)
			added_paths[item.file_path] = true
			
	return results

# --- Color Picker ---

func _get_color_results(arg: String) -> Array[SearchData]:
	var results: Array[SearchData] = []
	var input = arg.strip_edges()
	
	# If no input, show help options
	if input.is_empty():
		# Pick option
		var pick_item = SearchData.new()
		pick_item.type = SearchData.Type.ACTION
		pick_item.file_name = "-color pick"
		pick_item.file_path = "color_pick"
		pick_item.desc = "Open color picker dialog"
		pick_item.icon_name = "ColorPick"
		pick_item.score = 1000
		results.append(pick_item)
		
		# Example hints
		var hint1 = SearchData.new()
		hint1.type = SearchData.Type.COMMAND
		hint1.file_name = "-color #FF5500"
		hint1.file_path = "-color "
		hint1.desc = "Try a hex color"
		hint1.icon_name = "Color"
		hint1.score = 900
		results.append(hint1)
		
		var hint2 = SearchData.new()
		hint2.type = SearchData.Type.COMMAND
		hint2.file_name = "-color rgb(255, 85, 0)"
		hint2.file_path = "-color "
		hint2.desc = "Try RGB format"
		hint2.icon_name = "Color"
		hint2.score = 800
		results.append(hint2)
		
		return results
	
	# Check for "pick" command
	if input.to_lower() == "pick":
		var pick_item = SearchData.new()
		pick_item.type = SearchData.Type.ACTION
		pick_item.file_name = "-color pick"
		pick_item.file_path = "color_pick"
		pick_item.desc = "Open color picker dialog"
		pick_item.icon_name = "ColorPick"
		pick_item.score = 1000
		results.append(pick_item)
		return results
	
	# Try to parse color
	var color: Color = Color.WHITE
	var valid = false
	var format_name = ""
	
	# Hex format: #RRGGBB or #RGB
	if input.begins_with("#"):
		var hex = input.substr(1)
		if hex.length() == 6 or hex.length() == 8:
			color = Color.html(input)
			valid = true
			format_name = "HEX"
		elif hex.length() == 3:
			# Expand short hex
			var expanded = "#" + hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
			color = Color.html(expanded)
			valid = true
			format_name = "HEX (short)"
	
	# RGB format: rgb(r, g, b) or just r, g, b
	elif input.to_lower().begins_with("rgb"):
		var match_str = input.substr(3).strip_edges()
		if match_str.begins_with("(") and match_str.ends_with(")"):
			match_str = match_str.substr(1, match_str.length() - 2)
		var parts = match_str.split(",")
		if parts.size() >= 3:
			var r = parts[0].strip_edges().to_int()
			var g = parts[1].strip_edges().to_int()
			var b = parts[2].strip_edges().to_int()
			color = Color(r / 255.0, g / 255.0, b / 255.0)
			valid = true
			format_name = "RGB"
	
	# Try direct Color name
	elif Color.html_is_valid("#" + input):
		color = Color.html("#" + input)
		valid = true
		format_name = "HEX"
	
	if valid:
		# Create result with color preview
		var gdscript_format = "Color(%.3f, %.3f, %.3f)" % [color.r, color.g, color.b]
		var hex_format = "#" + color.to_html(false).to_upper()
		
		# Copy as Color() format
		var item1 = SearchData.new()
		item1.type = SearchData.Type.ACTION
		item1.file_name = gdscript_format
		item1.file_path = "color_copy"
		item1.desc = "Copy as GDScript Color()"
		item1.icon_name = "ColorPick"
		item1.args = [gdscript_format]
		item1.score = 1000
		results.append(item1)
		
		# Copy as hex
		var item2 = SearchData.new()
		item2.type = SearchData.Type.ACTION
		item2.file_name = hex_format
		item2.file_path = "color_copy"
		item2.desc = "Copy as HEX"
		item2.icon_name = "Color"
		item2.args = [hex_format]
		item2.score = 900
		results.append(item2)
		
		# Copy as RGB
		var rgb_format = "rgb(%d, %d, %d)" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]
		var item3 = SearchData.new()
		item3.type = SearchData.Type.ACTION
		item3.file_name = rgb_format
		item3.file_path = "color_copy"
		item3.desc = "Copy as RGB"
		item3.icon_name = "Color"
		item3.args = [rgb_format]
		item3.score = 800
		results.append(item3)
	else:
		# Invalid color
		var item = SearchData.new()
		item.type = SearchData.Type.COMMAND
		item.file_name = "-color [invalid]"
		item.file_path = "-color "
		item.desc = "Try: #FF5500, rgb(255,85,0), or 'pick'"
		item.icon_name = "StatusWarning"
		item.score = 1000
		results.append(item)
	
	return results
