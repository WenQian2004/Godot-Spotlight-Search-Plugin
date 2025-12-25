@tool
extends RefCounted
class_name SpotlightConfig

## 配置管理器 - 使用 ProjectSettings 存储所有配置

# 配置键名
const SETTING_MAX_RESULTS = "addons/spotlight_search/config/max_results"
const SETTING_EXCLUDE_FOLDERS = "addons/spotlight_search/config/exclude_folders"
const SETTING_ALLOWED_EXTENSIONS = "addons/spotlight_search/config/allowed_extensions"
const SETTING_ENABLED_EXTENSIONS = "addons/spotlight_search/config/enabled_extensions"
const SETTING_EXTERNAL_EXTENSIONS = "addons/spotlight_search/config/external_extensions"
const SETTING_MAX_PREVIEW_LENGTH = "addons/spotlight_search/config/max_preview_length"

# 默认排除目录
const DEFAULT_EXCLUDES = [".git/", ".import/", ".godot/"]

# 默认允许的扩展名
const DEFAULT_EXTENSIONS = [
	"gd", "tscn", "scn", "tres", "res", 
	"png", "jpg", "jpeg", "svg", "webp", 
	"shader", "gdshader", "txt", "md", "json", "cfg", "ini"
]

# 注册所有设置项到 ProjectSettings
static func register_settings():
	# 最大结果数
	if not ProjectSettings.has_setting(SETTING_MAX_RESULTS):
		ProjectSettings.set_setting(SETTING_MAX_RESULTS, 50)
	ProjectSettings.set_initial_value(SETTING_MAX_RESULTS, 50)
	ProjectSettings.add_property_info({
		"name": SETTING_MAX_RESULTS,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
	"hint_string": "10,999"
	})
	
	# 排除目录
	if not ProjectSettings.has_setting(SETTING_EXCLUDE_FOLDERS):
		ProjectSettings.set_setting(SETTING_EXCLUDE_FOLDERS, PackedStringArray(DEFAULT_EXCLUDES))
	ProjectSettings.set_initial_value(SETTING_EXCLUDE_FOLDERS, PackedStringArray(DEFAULT_EXCLUDES))
	ProjectSettings.add_property_info({
		"name": SETTING_EXCLUDE_FOLDERS,
		"type": TYPE_PACKED_STRING_ARRAY
	})
	
	# 允许的扩展名 (新增)
	if not ProjectSettings.has_setting(SETTING_ALLOWED_EXTENSIONS):
		ProjectSettings.set_setting(SETTING_ALLOWED_EXTENSIONS, PackedStringArray(DEFAULT_EXTENSIONS))
	ProjectSettings.set_initial_value(SETTING_ALLOWED_EXTENSIONS, PackedStringArray(DEFAULT_EXTENSIONS))
	ProjectSettings.add_property_info({
		"name": SETTING_ALLOWED_EXTENSIONS,
		"type": TYPE_PACKED_STRING_ARRAY
	})
	
	# 启用的扩展 status map
	if not ProjectSettings.has_setting(SETTING_ENABLED_EXTENSIONS):
		ProjectSettings.set_setting(SETTING_ENABLED_EXTENSIONS, {})
	ProjectSettings.set_initial_value(SETTING_ENABLED_EXTENSIONS, {})
	
	# 外部扩展路径列表 (新增)
	if not ProjectSettings.has_setting(SETTING_EXTERNAL_EXTENSIONS):
		ProjectSettings.set_setting(SETTING_EXTERNAL_EXTENSIONS, PackedStringArray())
	ProjectSettings.set_initial_value(SETTING_EXTERNAL_EXTENSIONS, PackedStringArray())
	ProjectSettings.add_property_info({
		"name": SETTING_EXTERNAL_EXTENSIONS,
		"type": TYPE_PACKED_STRING_ARRAY
	})
	
	# 预览内容最大长度
	if not ProjectSettings.has_setting(SETTING_MAX_PREVIEW_LENGTH):
		ProjectSettings.set_setting(SETTING_MAX_PREVIEW_LENGTH, 500)
	ProjectSettings.set_initial_value(SETTING_MAX_PREVIEW_LENGTH, 500)
	ProjectSettings.add_property_info({
		"name": SETTING_MAX_PREVIEW_LENGTH,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "100,5000"
	})
	
	# 快捷键
	if not ProjectSettings.has_setting(SETTING_SHORTCUT):
		ProjectSettings.set_setting(SETTING_SHORTCUT, DEFAULT_SHORTCUT)
	ProjectSettings.set_initial_value(SETTING_SHORTCUT, DEFAULT_SHORTCUT)
	ProjectSettings.add_property_info({
		"name": SETTING_SHORTCUT,
		"type": TYPE_DICTIONARY
	})
	
	ProjectSettings.save()

# --- 最大结果数 ---
static func get_max_results() -> int:
	return ProjectSettings.get_setting(SETTING_MAX_RESULTS, 50)

static func set_max_results(value: int):
	ProjectSettings.set_setting(SETTING_MAX_RESULTS, value)
	ProjectSettings.save()

# --- 预览内容最大长度 ---
static func get_max_preview_length() -> int:
	return ProjectSettings.get_setting(SETTING_MAX_PREVIEW_LENGTH, 500)

static func set_max_preview_length(value: int):
	ProjectSettings.set_setting(SETTING_MAX_PREVIEW_LENGTH, value)
	ProjectSettings.save()

# --- 排除目录 ---
static func get_exclude_patterns() -> PackedStringArray:
	return ProjectSettings.get_setting(SETTING_EXCLUDE_FOLDERS, PackedStringArray(DEFAULT_EXCLUDES))

static func set_exclude_patterns(patterns: PackedStringArray):
	ProjectSettings.set_setting(SETTING_EXCLUDE_FOLDERS, patterns)
	ProjectSettings.save()

# --- 允许的扩展名 (新增) ---
static func get_allowed_extensions() -> PackedStringArray:
	return ProjectSettings.get_setting(SETTING_ALLOWED_EXTENSIONS, PackedStringArray(DEFAULT_EXTENSIONS))

static func set_allowed_extensions(exts: PackedStringArray):
	ProjectSettings.set_setting(SETTING_ALLOWED_EXTENSIONS, exts)
	ProjectSettings.save()

static func add_exclude_pattern(pattern: String):
	var current = get_exclude_patterns()
	if pattern not in current:
		var new_patterns = PackedStringArray(current)
		new_patterns.append(pattern)
		set_exclude_patterns(new_patterns)

static func remove_exclude_pattern(pattern: String):
	var current = get_exclude_patterns()
	var new_patterns = PackedStringArray()
	for p in current:
		if p != pattern:
			new_patterns.append(p)
	set_exclude_patterns(new_patterns)

# --- 扩展启用状态 ---
static func get_enabled_extensions() -> Dictionary:
	return ProjectSettings.get_setting(SETTING_ENABLED_EXTENSIONS, {})

static func is_extension_enabled(extension_id: String) -> bool:
	var enabled = get_enabled_extensions()
	# 默认启用
	return enabled.get(extension_id, true)

static func set_extension_enabled(extension_id: String, enabled: bool):
	var current = get_enabled_extensions().duplicate()
	current[extension_id] = enabled
	ProjectSettings.set_setting(SETTING_ENABLED_EXTENSIONS, current)
	ProjectSettings.save()

static func toggle_extension(extension_id: String) -> bool:
	var is_enabled = is_extension_enabled(extension_id)
	set_extension_enabled(extension_id, not is_enabled)
	return not is_enabled

# --- 外部扩展 ---
static func get_external_extensions() -> PackedStringArray:
	return ProjectSettings.get_setting(SETTING_EXTERNAL_EXTENSIONS, PackedStringArray())

static func add_external_extension(path: String):
	var paths = get_external_extensions()
	if path not in paths:
		paths.append(path)
		ProjectSettings.set_setting(SETTING_EXTERNAL_EXTENSIONS, paths)
		ProjectSettings.save()

static func remove_external_extension(path: String):
	var paths = get_external_extensions()
	if path in paths:
		var new_paths = PackedStringArray()
		for p in paths:
			if p != path: new_paths.append(p)
		ProjectSettings.set_setting(SETTING_EXTERNAL_EXTENSIONS, new_paths)
		ProjectSettings.save()

# --- 快捷键配置 ---
const SETTING_SHORTCUT = "addons/spotlight_search/config/shortcut"
const DEFAULT_SHORTCUT = {
	"keycode": KEY_Q,
	"ctrl_pressed": false,
	"shift_pressed": false,
	"alt_pressed": true,
	"meta_pressed": false
}

static func get_shortcut() -> Dictionary:
	return ProjectSettings.get_setting(SETTING_SHORTCUT, DEFAULT_SHORTCUT)

static func set_shortcut(shortcut: Dictionary):
	ProjectSettings.set_setting(SETTING_SHORTCUT, shortcut)
	ProjectSettings.save()

static func reset_shortcut_to_default():
	set_shortcut(DEFAULT_SHORTCUT)

static func is_event_shortcut(event: InputEventKey) -> bool:
	var shortcut = get_shortcut()
	if shortcut.is_empty(): return false
	
	if event.keycode != shortcut.get("keycode", 0): return false
	if event.ctrl_pressed != shortcut.get("ctrl_pressed", false): return false
	if event.shift_pressed != shortcut.get("shift_pressed", false): return false
	if event.alt_pressed != shortcut.get("alt_pressed", false): return false
	if event.meta_pressed != shortcut.get("meta_pressed", false): return false
	
	return true
