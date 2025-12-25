@tool
extends SpotlightExtension

const SCORE_BASE = 100

func _init():
	pass

func get_id() -> String:
	return "wenqian.open_editors"

func get_display_name() -> String:
	return "Open Editors Switcher"

func get_author() -> String:
	return "WenQian"

func get_version() -> String:
	return "1.0.0"

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = text.strip_edges().to_lower()
	
	# Check command activation: "-tabs"
	var is_active = false
	var query_str = ""
	
	# 1. Context check (if user enters via menu)
	if not context.is_empty():
		var last = context.back()
		if last.get_unique_id() == "cmd.tabs":
			is_active = true
			query_str = search_term
			
	# 2. Prefix / Suggestion check
	if not is_active and context.is_empty():
		if text.begins_with("-tabs"):
			is_active = true
			var parts = text.split(" ", false, 1)
			if parts.size() > 1:
				query_str = parts[1].to_lower()
			else:
				query_str = ""
		
		# Self-suggestion logic: If text matches "-tabs" partially
		elif "-tabs".begins_with(text) or text == "":
			# Only show if text starts with "-" or is empty (optional, to avoid clutter)
			if text.begins_with("-") or text == "":
				var score = SCORE_BASE
				if text != "":
					var match_res = SpotlightFuzzySearch.fuzzy_match(text, "-tabs")
					if match_res.matched:
						score = match_res.score
				else:
					score = 10 # Low score for empty query so it doesn't block others
				
				var cmd_item = CommandResult.new(
					"cmd.tabs",
					"-tabs",
					"Switch Open Editors",
					EditorInterface.get_editor_theme().get_icon("GuiTab", "EditorIcons"),
					Callable(),
					true # is_category
				)
				cmd_item.tags = ["Command", "ThirdParty"]
				cmd_item.score = score
				results.append(cmd_item)
	
	if is_active:
		results.append_array(_get_open_items(query_str))
	
	return results

# 恢复收藏的指令项
func resolve_item(id: String) -> SpotlightResultItem:
	if id == "cmd.tabs":
		var cmd_item = CommandResult.new(
			"cmd.tabs",
			"-tabs",
			"Switch Open Editors",
			EditorInterface.get_editor_theme().get_icon("GuiTab", "EditorIcons"),
			Callable(),
			true # is_category
		)
		cmd_item.tags = ["Command", "ThirdParty"]
		return cmd_item
	return null

func _get_open_items(query: String) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	
	# 1. Scripts
	var open_scripts = EditorInterface.get_script_editor().get_open_scripts()
	var script_icon = EditorInterface.get_editor_theme().get_icon("Script", "EditorIcons")
	
	for script in open_scripts:
		var path = script.resource_path
		var name = path.get_file()
		
		var score = 0
		if query.is_empty():
			score = SCORE_BASE
		else:
			# Fuzzy match against filename
			var match_res = SpotlightFuzzySearch.fuzzy_match(query, name)
			if match_res.matched:
				score = match_res.score
			else:
				continue
		
		# Create Result
		var item = CommandResult.new(
			"tab.script." + path,
			name,
			"Script: " + path,
			script_icon,
			func(): EditorInterface.edit_resource(script),
			false
		)
		item.tags = ["Tab", "Script"]
		item.score = score
		results.append(item)
		
	# 2. Scenes
	var open_scenes = EditorInterface.get_open_scenes()
	var scene_icon = EditorInterface.get_editor_theme().get_icon("PackedScene", "EditorIcons")
	
	for path in open_scenes:
		var name = path.get_file()
		
		var score = 0
		if query.is_empty():
			score = SCORE_BASE
		else:
			var match_res = SpotlightFuzzySearch.fuzzy_match(query, name)
			if match_res.matched:
				score = match_res.score
			else:
				continue
				
		var item = CommandResult.new(
			"tab.scene." + path,
			name,
			"Scene: " + path,
			scene_icon,
			func(): EditorInterface.open_scene_from_path(path),
			false
		)
		item.tags = ["Tab", "Scene"]
		item.score = score
		results.append(item)
		
	# Sort
	results.sort_custom(func(a, b): return a.score > b.score)
	
	return results
