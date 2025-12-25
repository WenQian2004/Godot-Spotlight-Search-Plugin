@tool
extends PopupPanel

const SpotlightInput = preload("res://addons/spotlight_search/core/input_manager.gd")
const SpotlightConfig = preload("res://addons/spotlight_search/core/config_manager.gd")

# 引入列表项场景
var LIST_ITEM_SCENE: PackedScene
var FILE_PREVIEW_SCENE: PackedScene
var DESC_PREVIEW_SCENE: PackedScene
var ACTION_BUTTON_SCENE: PackedScene

# 状态
var current_items: Array[SpotlightResultItem] = []
var selected_index: int = 0
var context_stack: Array[SpotlightResultItem] = [] # 存储当前指令层级

# --- 配置常量 ---
const DEFAULT_WIDTH = 600
const EXPANDED_WIDTH = 900
const WIN_HEIGHT = 550

# --- 节点引用 (路径必须与场景结构一致) ---
@onready var search_input = $BackgroundPanel/MainLayout/HeaderPanel/Padding/TopBar/HBox/SearchInput
@onready var breadcrumbs_container = $BackgroundPanel/MainLayout/HeaderPanel/Padding/TopBar/HBox/Breadcrumbs
@onready var result_container = $BackgroundPanel/MainLayout/BodySplit/LeftScroll/ResultList
@onready var right_panel = $BackgroundPanel/MainLayout/BodySplit/RightPanel
@onready var content_container = $BackgroundPanel/MainLayout/BodySplit/RightPanel/ContentPadding

# 状态
var is_expanded: bool = false
var _user_manually_closed_panel: bool = false # 用户是否手动关闭了右侧面板
var _last_visible_time: int = 0 # 上次可见的时间戳，用于判断是否需要传送效果
const TELEPORT_THRESHOLD_MS = 500 # 500ms 内再次打开则使用传送效果
var is_showing_favorites: bool = false # 是否正在显示收藏列表

func _ready():
	# 动态加载场景
	var base_path = get_script().resource_path.get_base_dir().get_base_dir().get_base_dir().get_base_dir()
	LIST_ITEM_SCENE = load(base_path + "/ui/components/list_item/list_item.tscn")
	FILE_PREVIEW_SCENE = load(base_path + "/ui/preview_templates/preview_file.tscn")
	DESC_PREVIEW_SCENE = load(base_path + "/ui/preview_templates/preview_desc.tscn")
	ACTION_BUTTON_SCENE = load(base_path + "/ui/components/action_button/action_button.tscn")
	
	# 1. PopupPanel 样式设置
	var style = StyleBoxFlat.new()
	style.bg_color = get_theme_color("base_color", "Editor") # Color(0.12, 0.13, 0.14, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = get_theme_color("dark_color_3", "Editor") 
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)
	
	# 2. UI 初始化状态
	size = Vector2i(DEFAULT_WIDTH, WIN_HEIGHT)
	
	# 右侧边栏默认开启
	toggle_right_panel(true, true)
	
	# 3. 信号连接
	search_input.text_changed.connect(_on_search_text_changed)
	search_input.gui_input.connect(_on_search_input_gui_input)
	
	add_to_group("spotlight_window")

	# 8. 触发初始查询
	_on_search_text_changed("")

func set_search_text(text: String):
	search_input.text = text
	search_input.caret_column = text.length()
	_on_search_text_changed(text)
	popup_hide.connect(_on_popup_hide)

func _on_popup_hide():
	# 记录关闭时间，用于传送效果判断
	_last_visible_time = Time.get_ticks_msec()
	# 当 Popup 隐藏时，返回焦点给编辑器
	call_deferred("_return_focus_to_editor")

func _return_focus_to_editor():
	var editor_interface = EditorInterface
	if not editor_interface: return

	# 1. 优先尝试 Script Editor
	var script_editor = editor_interface.get_script_editor()
	if script_editor and script_editor.is_visible_in_tree() and script_editor.focus_mode != Control.FOCUS_NONE:
		script_editor.grab_focus()
		return

	# 2. 尝试 Inspector
	var inspector = editor_interface.get_inspector()
	if inspector and inspector.is_visible_in_tree() and inspector.focus_mode != Control.FOCUS_NONE:
		inspector.grab_focus()
		return

	# 3. 尝试 FileSystem Dock
	var fs_dock = editor_interface.get_file_system_dock()
	if fs_dock and fs_dock.is_visible_in_tree() and fs_dock.focus_mode != Control.FOCUS_NONE:
		fs_dock.grab_focus()
		return
		
	# 4. Fallback: Base Control
	var base = editor_interface.get_base_control()
	if base and base.is_visible_in_tree() and base.focus_mode != Control.FOCUS_NONE:
		base.grab_focus()

# --- 核心：打开逻辑 (鼠标跟随 + 安全区) ---
func open_spotlight():
	# 1. 重置 UI
	search_input.text = ""
	is_showing_favorites = false
	
	# 如果已经在显示，就做个移动动画
	var was_visible = visible
	
	# 2. 获取屏幕信息
	var mouse_pos = DisplayServer.mouse_get_position()
	var screen_id = DisplayServer.get_screen_from_rect(Rect2(Vector2(mouse_pos), Vector2.ONE))
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	# 3. 计算目标位置 (以鼠标为中心，对齐输入框中点)
	# 输入框在顶部，所以垂直方向上，鼠标大约位于窗口顶部 (或稍微上方)
	# 水平方向上，窗口中心对齐鼠标
	var target_x = mouse_pos.x - (size.x / 2)
	var target_y = mouse_pos.y
	
	# 4. 边界检测 (Safe Zone Logic)
	# 左边界
	if target_x < screen_rect.position.x:
		target_x = screen_rect.position.x + 10
	# 右边界
	elif target_x + size.x > screen_rect.end.x:
		target_x = screen_rect.end.x - size.x - 10
	# 下边界
	if target_y + size.y > screen_rect.end.y:
		target_y = mouse_pos.y - size.y - 10 # 翻转到上方
	
	var target_pos = Vector2i(target_x, target_y)
	
	# 5. 判断是否需要传送效果
	# 如果当前可见，或者刚刚关闭（500ms内），使用传送效果
	var should_teleport = visible
	if not visible:
		var time_since_close = Time.get_ticks_msec() - _last_visible_time
		should_teleport = time_since_close < TELEPORT_THRESHOLD_MS and _last_visible_time > 0
	
	if should_teleport:
		_teleport_to(target_pos)
		return
	
	# 6. 首次打开 - 带入场动画
	var content = $BackgroundPanel
	content.modulate.a = 0.0
	var original_pos = target_pos
	target_pos.y -= 20
	
	# 使用正确的尺寸（右侧面板默认开启）
	var target_size = Vector2i(EXPANDED_WIDTH if is_expanded else DEFAULT_WIDTH, WIN_HEIGHT)
	popup(Rect2i(target_pos, target_size))
	
	# 入场动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(content, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:y", float(original_pos.y), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# 7. 聚焦输入框
	await get_tree().process_frame
	if visible and search_input and search_input.focus_mode != Control.FOCUS_NONE:
		search_input.grab_focus()
	
	# 8. 触发初始查询
	_on_search_text_changed("")

func _teleport_to(target_pos: Vector2i):
	var content = $BackgroundPanel
	
	# 计算正确的尺寸
	var target_size = Vector2i(EXPANDED_WIDTH if is_expanded else DEFAULT_WIDTH, WIN_HEIGHT)
	
	# 如果面板不可见，直接在新位置打开（带入场动画）
	if not visible:
		content.modulate.a = 0.0
		popup(Rect2i(target_pos, target_size))
		
		# 入场动画
		var tween = create_tween()
		tween.tween_property(content, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		await get_tree().process_frame
		if visible and search_input and search_input.focus_mode != Control.FOCUS_NONE:
			search_input.grab_focus()
		_on_search_text_changed("")
		return
	
	# 面板已可见 - 传送动画 (淡出 -> 移动 -> 淡入)
	var tween = create_tween()
	tween.tween_property(content, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): 
		# 使用 popup 设置新位置和尺寸
		popup(Rect2i(target_pos, target_size))
		if search_input and search_input.focus_mode != Control.FOCUS_NONE:
			search_input.grab_focus()
	)
	tween.tween_property(content, "modulate:a", 1.0, 0.15)

# --- 核心：滑动面板动画 ---
func toggle_right_panel(show_panel: bool, instant: bool = false):
	# 如果状态未变，直接跳过
	if is_expanded == show_panel and not instant: return
	is_expanded = show_panel
	
	var target_win_width = EXPANDED_WIDTH if show_panel else DEFAULT_WIDTH
	var target_panel_width = 300 if show_panel else 0 # 右侧面板宽度
	
	# 重新计算窗口 X 位置以防止溢出屏幕右侧
	# (注意：Window.size 改变时，默认是向右扩展，如果不修正 position.x，可能会超出屏幕)
	if show_panel and not instant and visible:
		var screen_id = DisplayServer.get_screen_from_rect(Rect2(position, Vector2.ONE))
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
		if position.x + target_win_width > screen_rect.end.x:
			# 需要向左移
			var diff = (position.x + target_win_width) - screen_rect.end.x + 20
			create_tween().tween_property(self, "position:x", position.x - diff, 0.25)
	
	if instant:
		size.x = target_win_width
		right_panel.custom_minimum_size.x = target_panel_width
		right_panel.visible = show_panel
	else:
		# 使用 Tween 动画
		var tween = create_tween().set_parallel(true)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
		
		# 1. 窗口变宽
		tween.tween_property(self, "size:x", target_win_width, 0.25)
		
		# 2. 面板变宽
		if show_panel:
			right_panel.visible = true
			tween.tween_property(right_panel, "custom_minimum_size:x", target_panel_width, 0.25)
		else:
			# 收起: 先变窄，动画结束后隐藏
			tween.tween_property(right_panel, "custom_minimum_size:x", 0, 0.25)
			tween.chain().tween_callback(func(): right_panel.visible = false)


# --- 输入监听 ---
# --- 核心：输入导航 (键盘上下键) ---
func _input(event):
	if not visible: return
	
	# 必须是按键按下
	if not event is InputEventKey or not event.pressed:
		return

	# 优先检查是否是唤醒快捷键 (例如 Alt+Q)
	# 如果是，且当前已经显示，则视为“移动到新位置”的操作
	if SpotlightConfig.is_event_shortcut(event):
		open_spotlight()
		get_viewport().set_input_as_handled()
		return

	# 使用 InputManager 判断

	if SpotlightInput.is_action(event, SpotlightInput.ACT_NAV_BACK):
		if not context_stack.is_empty():
			_go_back()
		else:
			hide()
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_NAV_DOWN):
		selected_index = min(selected_index + 1, current_items.size() - 1)
		_update_selection_visual()
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_NAV_UP):
		selected_index = max(selected_index - 1, 0)
		_update_selection_visual()
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_EXECUTE):
		if current_items.is_empty(): return
		var item = current_items[selected_index]
		if item.type == SpotlightResultItem.ItemType.LEAF:
			_execute_item(item)
		else:
			toggle_right_panel(true)
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_NAV_IN):
		if current_items.is_empty(): return
		var item = current_items[selected_index]
		if item.type == SpotlightResultItem.ItemType.CATEGORY:
			_go_into_category(item)
		elif item.get_preview_type() == SpotlightResultItem.PreviewType.CUSTOM and right_panel.visible:
			# 尝试聚焦右侧面板中的第一个控件
			var controls = content_container.get_children()
			if not controls.is_empty():
				var content = controls[0]
				# 尝试寻找 content 内部的 focusable
				if content.focus_mode != Control.FOCUS_NONE:
					content.grab_focus()
				else:
					# 简单粗暴：寻找第一个可聚焦子节点
					var next = content.find_next_valid_focus()
					if next: next.grab_focus()
		else:
			search_input.text = item.title
			search_input.caret_column = search_input.text.length()
			_on_search_text_changed(search_input.text)
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_PANEL_TOGGLE):
		_user_manually_closed_panel = false
		toggle_right_panel(true)
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_PANEL_CLOSE):
		_user_manually_closed_panel = true
		toggle_right_panel(false)
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_FAV_TOGGLE):
		# Shift + Up: 切换收藏
		if not current_items.is_empty():
			var item = current_items[selected_index]
			var FavManager = get_favorites_manager()
			FavManager.toggle_favorite(item.get_unique_id())
			# 刷新当前列表项的 UI 显示 (需要 list_item 支持)
			_refresh_current_item_ui()
		get_viewport().set_input_as_handled()
		
	elif SpotlightInput.is_action(event, SpotlightInput.ACT_SHOW_FAVS):
		# Shift + Down: 显示所有收藏
		_show_all_favorites()
		get_viewport().set_input_as_handled()

func _refresh_current_item_ui():
	var children = result_container.get_children()
	if selected_index >= 0 and selected_index < children.size():
		children[selected_index].update_favorite_status()

func _show_all_favorites():
	# 如果当前已经在显示收藏，则切回搜索结果
	if is_showing_favorites:
		is_showing_favorites = false
		# 恢复已有的搜索结果
		_on_search_text_changed(search_input.text)
		return

	# 显示所有收藏的项目
	is_showing_favorites = true

	var results: Array[SpotlightResultItem] = []
	
	var manager = get_node("/root/SpotlightManager")
	if manager:
		results = manager.get_all_favorites_as_items()

	if results.is_empty():
		# 没有收藏时显示提示
		search_input.placeholder_text = "暂无收藏项目"
	else:
		search_input.placeholder_text = "收藏列表"
	
	_update_list_ui(results)

func get_favorites_manager():
	return SpotlightFavoritesManager

# --- 核心：搜索变动时触发 ---
func _on_search_text_changed(new_text):
	# 只要输入的搜索文本变化 (不是我们的 toggle 操作导致的)，就重置 flag
	if not is_showing_favorites:
		pass
	else:
		# 如果之前是显示收藏，现在用户输入了，就自动退出收藏模式
		is_showing_favorites = false
	
	var manager = get_node("/root/SpotlightManager")
	if manager:
		var results = manager.query_all(new_text, context_stack)
		_update_list_ui(results)
		
		# --- 自动转换标签逻辑 ---
		# 当输入以空格结尾，且当前列表第一项完全匹配输入的指令（不含空格），且该项是目录类型
		if new_text.ends_with(" ") and not results.is_empty():
			var first_item = results[0]
			var input_cmd = new_text.strip_edges()
			
			# 确保是 Category 且 Title 或 唯一 ID 匹配
			if first_item.type == SpotlightResultItem.ItemType.CATEGORY:
				var unique_id = first_item.get_unique_id()
				# 检查 title 是否匹配 input_cmd (例如 "-gdscript")
				# 或者 ID 是否匹配 "filter." + input_cmd
				if first_item.title == input_cmd or unique_id == "filter." + input_cmd or unique_id == "cmd." + input_cmd or unique_id == input_cmd:
					# 自动执行该项进入下一级
					_execute_item(first_item)
					return
	
	# 每次输入，更新面包屑
	_update_breadcrumbs()

func _on_search_input_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		if search_input.text.is_empty():
			# 文本为空时按删除键，回退一级
			_go_back()
			search_input.accept_event()

# --- 核心：更新列表 UI ---
func _update_list_ui(items: Array[SpotlightResultItem]):
	current_items = items
	selected_index = 0 # 重置选中
	
	# 清空旧列表
	for child in result_container.get_children():
		child.queue_free()
		
	# 生成新列表
	for i in range(items.size()):
		var item = items[i]
		var ui = LIST_ITEM_SCENE.instantiate()
		result_container.add_child(ui)
		ui.setup(item)
		
		# 连接信号 (鼠标点击)
		ui.item_selected.connect(func(_it): 
			selected_index = i
			_update_selection_visual()
		)
		ui.item_executed.connect(func(_it): _execute_item(_it))
		
	# 刷新选中状态
	_update_selection_visual()

# --- 核心：视觉高亮与预览 ---
func _update_selection_visual():
	var children = result_container.get_children()
	if children.is_empty(): 
		# 清空右侧面板
		_update_preview_panel(null)
		return
		
	for i in range(children.size()):
		var child = children[i]
		child.set_highlight(i == selected_index)
		
		# 自动滚动到选中项
		if i == selected_index:
			_ensure_visible(child)

	# 更新右侧面板数据
	if selected_index >= 0 and selected_index < current_items.size():
		_update_preview_panel(current_items[selected_index])

func _ensure_visible(control: Control):
	var scroll_container = result_container.get_parent() as ScrollContainer
	if not scroll_container: return
	
	# 计算目标 Item 相对于 ScrollContainer 的位置
	var item_top = control.position.y
	var item_bottom = item_top + control.size.y
	
	var scroll_val = scroll_container.scroll_vertical
	var viewport_height = scroll_container.size.y
	
	# 如果上方不可见
	if item_top < scroll_val:
		scroll_container.scroll_vertical = item_top
	# 如果下方不可见
	elif item_bottom > scroll_val + viewport_height:
		scroll_container.scroll_vertical = item_bottom - viewport_height

# --- 核心：执行 ---
func _execute_item(item: SpotlightResultItem):
	# 如果是目录类型，进入下级，不关闭窗口
	if item.type == SpotlightResultItem.ItemType.CATEGORY:
		_go_into_category(item)
		return

	# 记录历史
	var manager = get_node("/root/SpotlightManager")
	if manager:
		manager.add_history(item.get_unique_id())
		
	item.execute()
	
	# 执行后重置状态，以便下次打开时是初始界面
	context_stack.clear()
	search_input.text = ""
	_user_manually_closed_panel = false
	current_items.clear()
	
	hide() # 执行后关闭窗口

# 进入一个分类 (Tab)
func _go_into_category(category_item: SpotlightResultItem):
	context_stack.append(category_item)
	search_input.text = "" # 清空输入框
	_update_breadcrumbs()
	_on_search_text_changed("") # 重新查询子项

# 回退上一级 (Esc)
func _go_back():
	if not context_stack.is_empty():
		context_stack.pop_back()
		search_input.text = "" # 清空输入框
		_update_breadcrumbs()
		_on_search_text_changed("") # 重新查询当前层级项
	else:
		hide() # 如果在根目录，就关闭

# --- 核心：更新右侧预览面板 ---
# 重写这个函数，现在它将实例化不同的场景
func _update_preview_panel(item: SpotlightResultItem):
	#print("[Spotlight Preview] _update_preview_panel called, item: ", item)
	
	for child in content_container.get_children():
		child.queue_free() # 清空旧内容
		
	if item == null: 
		return
	
	# 如果用户之前手动关闭了面板，就不自动展开
	if not _user_manually_closed_panel:
		toggle_right_panel(true) # 有内容就展开
	
	var preview_control: Control = null
	var content = item.get_preview_content()
	
	#print("[Spotlight Preview] preview_type: ", item.get_preview_type())
	
	match item.get_preview_type():
		SpotlightResultItem.PreviewType.STANDARD_FILE:
			# 文件预览
			var file_preview_ui = FILE_PREVIEW_SCENE.instantiate()
			
			# 设置标题（使用递归查找）
			var title_lbl = file_preview_ui.find_child("TitleLabel", true, false)
			if title_lbl:
				title_lbl.text = item.title
				
				# 插入 Tags
				if not item.tags.is_empty():
					var parent = title_lbl.get_parent()
					if parent:
						var tags_bar = _create_tags_bar(item.tags)
						parent.add_child(tags_bar)
						# 尝试调整位置到 Title 下方
						parent.move_child(tags_bar, title_lbl.get_index() + 1)
			
			# 设置图标
			var icon_node = file_preview_ui.find_child("Icon", true, false)
			if icon_node:
				icon_node.texture = item.icon
			
			# 设置路径
			var path_container = file_preview_ui.find_child("PathContainer", true, false)
			var path_lbl = file_preview_ui.find_child("PathLabel", true, false)
			var path_text = content.get("text", "")
			#print("[Spotlight Preview] path_text: ", path_text)
			if path_lbl and path_text:
				path_lbl.text = path_text
				if path_container:
					path_container.visible = true
			else:
				if path_container:
					path_container.visible = false
			
			# 获取预览区域
			var code_preview = file_preview_ui.find_child("CodePreview", true, false)
			var code_panel = file_preview_ui.find_child("CodePreviewPanel", true, false)
			var image_preview = file_preview_ui.find_child("ImagePreview", true, false)
			var image_panel = file_preview_ui.find_child("ImagePreviewPanel", true, false)
			var preview_label = file_preview_ui.find_child("PreviewLabel", true, false)
			var preview_section = file_preview_ui.find_child("PreviewSection", true, false)
			
			# 调试输出
			#print("[Spotlight Preview] content keys: ", content.keys())
			
			# 显示代码或图片
			if content.has("code"):
				#print("[Spotlight Preview] Showing code preview, length: ", content.code.length())
				if code_preview:
					code_preview.text = content.code
				if code_panel:
					code_panel.visible = true
				if image_panel:
					image_panel.visible = false
				if preview_label:
					preview_label.text = "Code Preview"
			elif content.has("image_texture"):
				#print("[Spotlight Preview] Showing image preview")
				if image_preview:
					image_preview.texture = content.image_texture
				if image_panel:
					image_panel.visible = true
				if code_panel:
					code_panel.visible = false
				if preview_label:
					preview_label.text = "Image Preview"
			elif content.has("request_thumbnail"):
				# 异步加载缩略图 (用于 Scene 等)
				if image_preview:
					# 可以先设个默认图或者 Loading 状态
					image_preview.texture = null 
				if image_panel:
					image_panel.visible = true
				if code_panel:
					code_panel.visible = false
					
				if preview_label:
					preview_label.text = "Scene Preview"
					
				# 请求生成
				var previewer = EditorInterface.get_resource_previewer()
				if previewer:
					previewer.queue_resource_preview(item.file_path, self, "_on_thumbnail_loaded", image_preview)
			else:
				#print("[Spotlight Preview] No preview content")
				# 无预览内容
				if code_panel:
					code_panel.visible = false
				if image_panel:
					image_panel.visible = false
				if preview_label:
					preview_label.text = "No Preview"
			
			preview_control = file_preview_ui
			
			# 添加动作按钮
			var action_buttons = file_preview_ui.find_child("ActionButtons", true, false)
			if action_buttons:
				_add_action_buttons(action_buttons, item.get_actions())
			
		SpotlightResultItem.PreviewType.STANDARD_DESC:
			# 描述预览
			var desc_preview_ui = DESC_PREVIEW_SCENE.instantiate()
			desc_preview_ui.find_child("BigIcon").texture = item.icon
			var title_lbl = desc_preview_ui.find_child("TitleLabel")
			title_lbl.text = item.title
			
			# 插入 Tags
			if not item.tags.is_empty():
				var parent = title_lbl.get_parent()
				if parent:
					var tags_bar = _create_tags_bar(item.tags)
					parent.add_child(tags_bar)
					parent.move_child(tags_bar, title_lbl.get_index() + 1)
			
			desc_preview_ui.find_child("DescLabel").text = content.get("text", "")
			
			# 如果有快捷键提示，就显示
			var key_hint_grid = desc_preview_ui.find_child("KeyHintGrid")
			for action in item.get_actions():
				if not action.shortcut_text.is_empty():
					var hint_label = Label.new()
					hint_label.text = action.shortcut_text
					key_hint_grid.add_child(hint_label)
			
			preview_control = desc_preview_ui
			
		SpotlightResultItem.PreviewType.CUSTOM:
			# 自定义 UI
			preview_control = item.create_custom_preview()
			
	if preview_control:
		content_container.add_child(preview_control)
		# 确保自定义 UI 也能占据空间
		preview_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_control.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _create_tags_bar(tags: Array) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER # 居中对齐
	
	for tag in tags:
		var chip = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = get_theme_color("dark_color_3", "Editor") # Slightly lighter
		style.corner_radius_top_left = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		
		# 特殊颜色: Official
		if tag == "Official":
			style.bg_color = get_theme_color("accent_color", "Editor")
			style.bg_color.a = 0.15 # Very transparent
			style.border_width_left = 0
			# style.border_color = get_theme_color("accent_color", "Editor")
		
		chip.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.text = tag
		label.add_theme_font_size_override("font_size", 10)
		
		# Text color
		if tag == "Official":
			label.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
		else:
			label.add_theme_color_override("font_color", get_theme_color("font_color", "Editor").darkened(0.2))
			
		chip.add_child(label)
		hbox.add_child(chip)
		
	return hbox


# 辅助函数：添加动作按钮
func _add_action_buttons(parent_hbox: HBoxContainer, actions: Array[SpotlightAction]):
	for action in actions:
		var btn = ACTION_BUTTON_SCENE.instantiate()
		parent_hbox.add_child(btn)
		btn.setup(action)

func _update_breadcrumbs():
	# 清空旧的面包屑
	for child in breadcrumbs_container.get_children():
		child.queue_free()
	
	# 添加根面包屑
	# 遍历 context_stack
	# 如果没有 context，只显示 "Spotlight" 作为 placeholder 或者什么都不显示
	if context_stack.is_empty():
		search_input.placeholder_text = "Type to search..."
	else:
		search_input.placeholder_text = ""

	for item in context_stack:
		# 创建 Chip 容器
		var chip = PanelContainer.new()
		var chip_style = StyleBoxFlat.new()
		chip_style.bg_color = get_theme_color("dark_color_2", "Editor") # 深蓝灰色背景
		chip_style.corner_radius_top_left = 6
		chip_style.corner_radius_top_right = 6
		chip_style.corner_radius_bottom_left = 6
		chip_style.corner_radius_bottom_right = 6
		chip_style.content_margin_left = 8
		chip_style.content_margin_right = 8
		chip_style.content_margin_top = 2
		chip_style.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", chip_style)
		
		# Chip 文本
		var label = Label.new()
		label.text = item.title
		label.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor")) # 浅蓝色文字
		label.add_theme_font_size_override("font_size", 13)
		
		chip.add_child(label)
		breadcrumbs_container.add_child(chip)
		
		# 分隔符 (斜杠)
		var divider = Label.new()
		divider.text = " / "
		divider.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Editor"))
		breadcrumbs_container.add_child(divider)
			
	search_input.visible = true

func _on_thumbnail_loaded(path: String, preview: Texture2D, thumbnail_preview: Texture2D, userdata: Variant):
	var image_preview = userdata as TextureRect
	if not is_instance_valid(image_preview):
		return
		
	if preview:
		image_preview.texture = preview
	elif thumbnail_preview:
		image_preview.texture = thumbnail_preview
	else:
		# 加载失败
		pass 
