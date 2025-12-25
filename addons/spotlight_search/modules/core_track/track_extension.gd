@tool
extends SpotlightExtension

# 动态加载引用
var COMMAND_RESULT_SCRIPT
var FUZZY_SEARCH
const SCORE_BASE = 100
const TRACK_GROUP = "spotlight_tracked"

# Inner class for Track Results with Drag Support
class TrackNodeResult:
	extends CommandResult
	
	var target_node_path: NodePath
	
	func get_drag_data() -> Variant:
		# Return text format for GDScript usage ($Path)
		var p_str = str(target_node_path)
		var text = "$" + p_str
		# Handle spaces in path
		if " " in p_str:
			text = '$"%s"' % p_str
			
		return text

func _init():
	pass

func get_id() -> String:
	return "core.track"

func get_display_name() -> String:
	return "Scene Node Tracker"

func get_author() -> String:
	return "Godot Engine"

func get_version() -> String:
	return "1.1.0"

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = text.strip_edges().to_lower()
	
	# Determine Mode
	var mode = "none" # none, root, all, find
	
	if not context.is_empty():
		var last_id = context.back().get_unique_id()
		if last_id == "cmd.track":
			mode = "root"
		elif last_id == "cmd.track.all":
			mode = "all"
		elif last_id == "cmd.track.find":
			mode = "find"
	
	# Handle Direct Input Prefix (e.g. "-track -all")
	if mode == "none" and text.begins_with("-track"):
		var parts = text.split(" ", false)
		if parts.size() >= 2:
			var sub = parts[1]
			if sub == "-all":
				mode = "all"
				# Strip prefix "-track -all"
				# A simplistic way:
				var prefix_len = "-track -all".length()
				if text.length() > prefix_len:
					search_term = text.substr(prefix_len).strip_edges().to_lower()
				else:
					search_term = ""
			elif sub == "-find":
				mode = "find"
				var prefix_len = "-track -find".length()
				if text.length() > prefix_len:
					search_term = text.substr(prefix_len).strip_edges().to_lower()
				else:
					search_term = ""
			else:
				# "-track something" -> Default to root mode with query
				mode = "root"
				# Strip "-track"
				search_term = text.substr(6).strip_edges().to_lower()
		else:
			# Just "-track"
			mode = "root"
			search_term = ""

	# Execute Logic based on Mode
	if mode == "root":
		# Only show sub-commands. No direct search.
		# User must select a mode (Tab/Enter) to proceed.
		
		# Define commands
		var cmd_all = { "id": "cmd.track.all", "key": "-all", "desc": "Search ALL nodes in scene", "icon": "Search" }
		var cmd_find = { "id": "cmd.track.find", "key": "-find", "desc": "Search tracked nodes (Favorites)", "icon": "Favorites" }
		
		var cmds = [cmd_all, cmd_find]
		
		for c in cmds:
			var show = false
			var score = 0
			
			if search_term.is_empty():
				show = true
				score = 100
			else:
				# Simple strict matching for commands
				if c.key.begins_with(search_term):
					show = true
					score = 100
				elif search_term.begins_with("-") and c.key.begins_with(search_term):
					show = true
					score = 100
			
			if show:
				var item = _create_subcommand(c.id, c.key, c.desc, c.icon, score)
				results.append(item)
			
	elif mode == "all":
		results = _search_nodes(search_term, false) # recursive = true, tracked_only = false
		
	elif mode == "find":
		results = _search_nodes(search_term, true) # tracked_only = true
		
	return results

func _create_subcommand(id: String, title: String, desc: String, icon_name: String, score: int) -> SpotlightResultItem:
	var icon = EditorInterface.get_editor_theme().get_icon(icon_name, "EditorIcons")
	var item = CommandResult.new(
		id,
		title,
		desc,
		icon,
		Callable(), # No action, just category
		true # Is Category
	)
	item.tags = ["Track", "Command"]
	item.score = score
	return item

func _search_nodes(query: String, tracked_only: bool) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var root = EditorInterface.get_edited_scene_root()
	
	if not root:
		return results
		
	var target_nodes = []
	
	if tracked_only:
		# Search in group
		var nodes = root.get_tree().get_nodes_in_group(TRACK_GROUP)
		# Filter nodes that belong to current scene (scene root or below)
		for n in nodes:
			if n == root or root.is_ancestor_of(n):
				target_nodes.append(n)
	else:
		# Search all
		_collect_nodes(root, target_nodes)
	
	for node in target_nodes:
		if not is_instance_valid(node): continue
		
		var score = 0
		if query.is_empty():
			score = SCORE_BASE
		else:
			var match_res = SpotlightFuzzySearch.fuzzy_match(query, node.name)
			if match_res.matched:
				score = match_res.score
			else:
				continue
		
		# Create Result Item
		var icon = EditorInterface.get_editor_theme().get_icon(node.get_class(), "EditorIcons")
		var node_path = root.get_path_to(node)
		var desc = str(node_path)
		
		# Use TrackNodeResult instead of generic CommandResult
		var item = TrackNodeResult.new(
			"track.node." + str(node_path),
			node.name,
			desc,
			icon,
			func(): _select_node(node),
			false
		)
		item.target_node_path = node_path
		
		item.tags = ["Node"]
		if tracked_only or node.is_in_group(TRACK_GROUP):
			item.tags.append("Tracked")
			score += 50 # Bonus for tracked nodes
			
		item.score = score
		results.append(item)
		
	results.sort_custom(func(a, b): return a.score > b.score)
	
	if results.size() > 50:
		results.resize(50)
		
	return results

func _collect_nodes(node: Node, target_array: Array):
	target_array.append(node)
	for child in node.get_children():
		_collect_nodes(child, target_array)

func _select_node(node: Node):
	if is_instance_valid(node):
		var selection = EditorInterface.get_selection()
		selection.clear()
		selection.add_node(node)
		print("[Spotlight] Selected node: ", node.name)
	else:
		print("[Spotlight] Node is no longer valid")
