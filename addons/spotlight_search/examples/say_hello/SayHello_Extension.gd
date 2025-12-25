@tool
extends SpotlightExtension

## WenQian 第三方扩展示例
## 演示多级嵌套命令和自定义预览面板的用法
## 作者: WenQian

const SCORE_BASE = 100

func _init():
	pass

# --- 扩展元信息 ---

func get_id() -> String:
	return "wenqian.hello"

func get_display_name() -> String:
	return "WenQian Hello"

func get_author() -> String:
	return "WenQian"  # 第三方作者名

func get_version() -> String:
	return "1.0.0"

# --- 命令定义 ---
# 顶级命令: -hello
# 子命令: -greet, -say
# -say 有自定义预览面板

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = text.to_lower()
	
	# ============================================
	# 1. 顶层：显示 -hello 命令
	# ============================================
	if context.is_empty():
		# 只有在命令模式下才显示
		if search_term.begins_with("-") or search_term.is_empty():
			var cmd_text = "-hello"
			var match_score = SCORE_BASE
			
			if not search_term.is_empty():
				var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, cmd_text)
				if not match_res.matched:
					return results
				match_score = match_res.score
			
			var icon = _get_icon("Node")
			var cmd = CommandResult.new(
				"wenqian.hello",      # ID
				"-hello",             # Title
				"WenQian's greeting commands",  # Description
				icon,
				Callable(),           # 无回调，因为是 Category
				true                  # is_category = true
			)
			cmd.tags = ["WenQian", "Community"]
			cmd.score = match_score
			results.append(cmd)
	
	# ============================================
	# 2. 第二级：在 -hello 上下文中显示子命令
	# ============================================
	elif context.size() == 1:
		var last_item = context.back()
		if last_item.get_unique_id() == "wenqian.hello":
			# 子命令定义
			var subcommands = [
				{
					"id": "wenqian.hello.greet",
					"title": "-greet",
					"desc": "Print a friendly greeting message",
					"icon": "Popup",
					"callback": func(): print("Hello from WenQian! 👋"),
					"is_category": false,
					"tags": ["WenQian", "Action"]
				},
				{
					"id": "wenqian.hello.say",
					"title": "-say",
					"desc": "Say something with custom input",
					"icon": "TextEdit",
					"callback": Callable(),  # 无回调，由自定义面板处理
					"is_category": false,  # 不是 Category，但有自定义预览
					"tags": ["WenQian", "Interactive"],
					"custom": true  # 标记使用自定义 Result
				},
				{
					"id": "wenqian.hello.nested",
					"title": "-nested",
					"desc": "Demonstrate deeper nesting",
					"icon": "Tree",
					"callback": Callable(),
					"is_category": true,  # 这是一个 Category，可以继续嵌套
					"tags": ["WenQian", "Category"]
				}
			]
			
			for sub in subcommands:
				var match_score = SCORE_BASE
				if not search_term.is_empty():
					var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, sub.title)
					if not match_res.matched:
						continue
					match_score = match_res.score
				
				var icon = _get_icon(sub.icon)
				var cmd: SpotlightResultItem
				
				# 如果是自定义类型，使用 SayResult
				if sub.get("custom", false):
					cmd = SayResult.new(
						sub.id,
						sub.title,
						sub.desc,
						icon
					)
				else:
					cmd = CommandResult.new(
						sub.id,
						sub.title,
						sub.desc,
						icon,
						sub.callback,
						sub.is_category
					)
				
				cmd.tags = sub.tags
				cmd.score = match_score
				results.append(cmd)
	
	# ============================================
	# 3. 第三级：在 -nested 上下文中显示更深层命令
	# ============================================
	elif context.size() == 2:
		var last_item = context.back()
		if last_item.get_unique_id() == "wenqian.hello.nested":
			var deep_commands = [
				{
					"id": "wenqian.hello.nested.deep1",
					"title": "-deep-action",
					"desc": "A deeply nested action",
					"icon": "AudioListener2D",
					"callback": func(): print("Deep action executed!"),
					"tags": ["WenQian", "Deep"]
				},
				{
					"id": "wenqian.hello.nested.deep2",
					"title": "-another-deep",
					"desc": "Another deeply nested command",
					"icon": "Animation",
					"callback": func(): print("Another deep action!"),
					"tags": ["WenQian", "Deep"]
				}
			]
			
			for sub in deep_commands:
				var match_score = SCORE_BASE
				if not search_term.is_empty():
					var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, sub.title)
					if not match_res.matched:
						continue
					match_score = match_res.score
				
				var icon = _get_icon(sub.icon)
				var cmd = CommandResult.new(
					sub.id,
					sub.title,
					sub.desc,
					icon,
					sub.callback,
					false  # 叶子节点
				)
				cmd.tags = sub.tags
				cmd.score = match_score
				results.append(cmd)
	
	return results

# --- 辅助方法 ---

func _get_icon(icon_name: String) -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(icon_name, "EditorIcons")
