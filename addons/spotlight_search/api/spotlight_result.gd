@tool
extends RefCounted
class_name SpotlightResultItem

## 查询到的Item组件的实现

# 结果类型：LEAF=可执行/文件, CATEGORY=目录/文件夹
enum ItemType { LEAF, CATEGORY }
# 预览类型：FILE=标准文件, DESC=标准描述, CUSTOM=自定义控件
enum PreviewType { STANDARD_FILE, STANDARD_DESC, CUSTOM }

var type = ItemType.LEAF
var title: String = "Untitled"
var description: String = ""
var icon: Texture2D = null
var score: float = 0.0 # 匹配度
var tags: Array = [] # 标签列表 (e.g. ["Official", "Editor"])

# --- 核心交互 ---

# 主执行逻辑 (Enter / 双击)
func execute():
	pass

# --- 拖拽支持 ---
# 如果返回 null，则不可拖拽。
# 如果返回数据 (通常是 Dictionary)，则开启拖拽。
# 对于文件，通常返回: { "type": "files", "files": ["res://path.gd"] }
func get_drag_data() -> Variant:
	return null

# --- 预览相关 ---

func get_preview_type() -> PreviewType:
	return PreviewType.STANDARD_DESC

# 用于 Standard 模式的数据
# 包含字段: text (描述), code (代码片段), image (图片), sub_title (路径)
func get_preview_content() -> Dictionary:
	return { "text": "No description provided." }

# 用于 Custom 模式 (返回 Control 实例)
func create_custom_preview() -> Control:
	return null

# --- 动作列表 ---
func get_actions() -> Array[SpotlightAction]:
	return []

# 获取唯一标识符 (用于收藏系统)
# 默认使用 title，子类应该重写此方法 (比如使用文件路径或命令ID)
func get_unique_id() -> String:
	return title
