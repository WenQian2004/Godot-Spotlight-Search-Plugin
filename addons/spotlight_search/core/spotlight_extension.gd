@tool
extends RefCounted
class_name SpotlightExtension

## 用户写的插件必须继承该节点
## 用于接入相关拓展

# 扩展唯一标识符
func get_id() -> String:
	return "unknown_extension"

# 扩展显示名称 (用于设置面板)
func get_display_name() -> String:
	return "Unknown Extension"

# 获取作者名 (用于标签显示)
func get_author() -> String:
	return ""

# 获取版本号
func get_version() -> String:
	return "1.0"

# 核心查询方法
# query: 用户输入的文本
# context: 当前所处的层级栈 (Array[SpotlightResultItem])
# 返回: Array[SpotlightResultItem]
func query(_text: String, _context: Array) -> Array[SpotlightResultItem]:
	return []
# 根据 ID 恢复 Item (用于收藏夹/历史记录)
# 返回: SpotlightResultItem 或 null
func resolve_item(_id: String) -> SpotlightResultItem:
	return null

# 生命周期
func _on_enable(): pass
func _on_disable(): pass
