@tool
extends PanelContainer

# 信号定义
signal item_selected(item)
signal item_executed(item)

# 数据引用
var result_item: SpotlightResultItem

# 节点引用 (根据刚才的结构)
@onready var icon_rect = $Padding/HBox/Icon
@onready var title_lbl = $Padding/HBox/TextGroup/Title
@onready var desc_lbl = $Padding/HBox/TextGroup/Desc
@onready var arrow_lbl = $Padding/HBox/Arrow

var fav_icon: Label

func _ready():
	# 确保鼠标能穿透 PanelContainer 并在 gui_input 捕获
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# 动态添加收藏图标
	fav_icon = Label.new()
	fav_icon.text = "★"
	fav_icon.visible = false
	var hbox = $Padding/HBox
	hbox.add_child(fav_icon)
	hbox.move_child(fav_icon, 1) # 插入到 Icon (index 0) 之后

# --- 初始化数据 ---
func setup(item: SpotlightResultItem):
	result_item = item
	
	# 1. 设置文本和图标
	title_lbl.text = item.title
	icon_rect.texture = item.icon
	
	# 2. 获取预览文本作为描述
	var content = item.get_preview_content()
	desc_lbl.text = content.get("text", "")
	
	# 3. 如果是目录类型，显示箭头
	arrow_lbl.visible = (item.type == SpotlightResultItem.ItemType.CATEGORY)
	
	# 4. 更新收藏状态
	update_favorite_status()

# --- 样式常量 ---
# --- 样式常量 ---
# (已移除硬编码颜色，改用 EditorTheme)


# 当前高亮状态
var _is_selected: bool = false

# --- 样式控制 ---
func set_highlight(active: bool):
	_is_selected = active
	_apply_style()

func _apply_style():
	var style = StyleBoxFlat.new()
	
	if _is_selected:
		# 选中状态: 深色背景 + 左侧 2px 蓝色高亮条
		style.bg_color = get_theme_color("dark_color_2", "Editor")
		style.border_width_left = 2
		style.border_color = get_theme_color("accent_color", "Editor")
	else:
		# 默认状态: 透明背景
		style.bg_color = Color.TRANSPARENT
		# 占位左边框，防止选中切换时文字跳动
		style.border_width_left = 2
		style.border_color = Color.TRANSPARENT
	
	add_theme_stylebox_override("panel", style)

func _set_hover(hovered: bool):
	if _is_selected:
		return  # 选中状态不受悬停影响
	
	var style = StyleBoxFlat.new()
	
	if hovered:
		# 悬停状态: 轻度深色背景，无高亮条
		style.bg_color = get_theme_color("dark_color_1", "Editor")
		style.border_width_left = 2
		style.border_color = Color.TRANSPARENT
	else:
		# 默认状态
		style.bg_color = Color.TRANSPARENT
		style.border_width_left = 2
		style.border_color = Color.TRANSPARENT
	
	add_theme_stylebox_override("panel", style)

func _notification(what):
	if what == NOTIFICATION_MOUSE_ENTER:
		_set_hover(true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_set_hover(false)

# --- 输入交互 ---
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.double_click:
				item_executed.emit(result_item)
			else:
				item_selected.emit(result_item)

# --- 拖拽逻辑 ---
func _get_drag_data(_at_position):
	if result_item == null: return null
	
	# 1. 获取数据 (如果返回 null 表示不可拖拽)
	var data = result_item.get_drag_data()
	if data == null: return null
	
	# 2. 设置拖拽时的“幽灵”预览图
	var preview_label = Label.new()
	preview_label.text = result_item.title
	
	# 给预览图加个背景，不然看不清
	var preview_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = get_theme_color("base_color", "Editor")
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	preview_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	
	margin.add_child(preview_label)
	preview_panel.add_child(margin)
	
	set_drag_preview(preview_panel)
	
	return data
	
func update_favorite_status():
	var FavManager = load("res://addons/spotlight_search/core/favorites_manager.gd")
	var is_fav = FavManager.is_favorite(result_item.get_unique_id())
	
	if is_fav:
		# 收藏状态：显示星号图标 + 金色
		fav_icon.visible = true
		fav_icon.modulate = get_theme_color("warning_color", "Editor") 
	else:
		# 非收藏状态：隐藏星号图标
		fav_icon.visible = false
	
	# 恢复标题颜色 (总是默认色)
	title_lbl.modulate = get_theme_color("font_color", "Editor")
