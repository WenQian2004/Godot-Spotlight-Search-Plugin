@tool
extends RefCounted

const SETTING_LANGUAGE = "addons/spotlight_search/config/language"

static var _current_lang: String = "en"
static var _initialized = false

static var TRANSLATIONS = {
	"en": {
		"placeholder_search": "Type to search...",
		"placeholder_initializing": "Initializing index...",
		"info_default": "Enter: Open | Shift+Enter: Add to '%s' | Drag: Drop",
		"info_history": "Shift+Up: History | Enter: Select | F: Toggle Favorite",
		"history_favorite": "Favorite command",
		"history_recent": "Recent command",
		"history_empty": "No history yet",
		"history_empty_desc": "Execute some commands first",
		"toast_favorite_added": "Added to favorites",
		"toast_favorite_removed": "Removed from favorites",
		"config_title": "Spotlight Configuration",
		"config_header": "Spotlight Settings",
		"config_general": "General",
		"config_max_results": "Max Results",
		"config_search_scope": "Search Scope",
		"config_exclude_folders": "Excluded Folders (One path per line):",
		"config_shortcuts": "Shortcuts",
		"config_activation_key": "Activation Key",
		"config_press_to_set": "Press to Set",
		"config_listening": "Listening...",
		"config_imported": "Imported Configurations",
		"config_import_json": "Import JSON Config...",
		"config_reload_all": "Reload All",
		"config_extensions": "Extensions",
		"config_ext_info": "Use 'Import JSON Config...' to add extension files.",
		"config_create_example": "Create Example Extension",
		"config_ext_hint": "Creates files in toolkit_extensions/, then import them",
		"config_maintenance": "Maintenance",
		"config_clear_cache": "Clear Cache & Re-initialize",
		"config_cancel": "Cancel",
		"config_save": "Save & Close",
		"config_language": "Language",
		"config_status_error": "Error: ",
		"config_status_disabled": "Disabled",
		"config_status_commands": "%d Commands",
		"config_enabled": "Enabled",
		"config_remove": "Remove",
		"config_dlg_ext_exists_title": "Extension Already Exists",
		"config_dlg_ext_exists_msg": "The Hello extension already exists at:\n%s\n\nDelete it first if you want to recreate.",
		"config_dlg_example_created_title": "Example Extension Created & Imported",
		"config_dlg_example_created_msg": "Created and imported Hello World extension!\n\nFiles:\n• %s\n• %s\n\nTry typing '-hello' in Spotlight!",
		"config_dlg_clear_title": "Clear Imported Configurations",
		"config_dlg_clear_msg": "This will remove all imported JSON configurations.\n\nNote: Extensions in 'toolkit_extensions/' and system commands will remain.\n\nContinue?",
		"tracker_add": "Add to Spotlight Search",
		"tracker_remove": "Remove from Spotlight Search",
		"ctx_copy_path": "Copy Path",
		"ctx_copy_name": "Copy File Name",
		"ctx_show_in_fs": "Show in FileSystem",
		"ctx_open_folder": "Open Containing Folder",
		"ctx_open_external": "Open in External Editor",
		"ctx_pin": "Pin to Top",
		"ctx_unpin": "Unpin from Top",
		"ctx_copy_node_path": "Copy Node Path ($...)",
		"ctx_copy_node_name": "Copy Node Name",
		"ctx_focus_scene": "Focus in Scene Tree",
		"ctx_duplicate": "Duplicate Node",
		"cmd_new_res": "Create New Resource...",
		"cmd_new_script": "Create GDScript",
		"cmd_new_shader": "Create Shader",
		"cmd_scene_ops": "Scene Operations",
		"cmd_reload_scene": "Reload Current Scene",
		"cmd_run_scene": "Run Current Scene (F6)",
		"cmd_save_scene": "Save Current Scene",
		"cmd_color_utils": "Color Utilities",
		"cmd_track_nodes": "Search Tracked Nodes",
		"cmd_browse_nodes": "Browse Engine Nodes",
		"cmd_browse_class": "Browse Class Methods & Properties",
		"cmd_filter_gd": "Filter: GDScript",
		"cmd_filter_scene": "Filter: Scenes",
		"cmd_filter_img": "Filter: Images",
		"cmd_filter_res": "Filter: Resources",
		"cmd_config": "Configuration",
		"cmd_open_settings": "Open Plugin Settings",
		"cmd_reload_project": "Reload Project",
		"cmd_quit_editor": "Quit Editor",
		"cmd_toggle_fullscreen": "Toggle Fullscreen",
		"ui_toolbar_tooltip": "Open Spotlight Settings",
		"ui_toolbar_btn": "Spotlight",
		"err_missing_action": "Error: Missing action_id in config",
		"cmd_requires": "Requires: ",
		"cmd_enter_filename": "Enter file name...",
		"cmd_create_prefix": "Create ",
		"cmd_create_in": " in ",
		"cmd_manual_open_settings": "Open Settings",
		"cmd_manual_open_settings_desc": "Open Project Settings > Spotlight Search",
		"config_json_filter": "JSON Configuration",
	},
	"zh": {
		"placeholder_search": "输入以搜索...",
		"placeholder_initializing": "正在初始化索引...",
		"info_default": "Enter: 打开 | Shift+Enter: 添加到 '%s' | 拖拽: 放置",
		"info_history": "Shift+Up: 历史 | Enter: 选择 | F: 切换收藏",
		"history_favorite": "收藏的命令",
		"history_recent": "最近使用",
		"history_empty": "暂无历史记录",
		"history_empty_desc": "先执行一些命令吧",
		"toast_favorite_added": "已添加到收藏",
		"toast_favorite_removed": "已从收藏移除",
		"config_title": "Spotlight 配置",
		"config_header": "Spotlight 设置",
		"config_general": "常规",
		"config_max_results": "最大结果数",
		"config_search_scope": "搜索范围",
		"config_exclude_folders": "排除文件夹 (每行一个路径):",
		"config_shortcuts": "快捷键",
		"config_activation_key": "激活按键",
		"config_press_to_set": "点击设置",
		"config_listening": "监听中...",
		"config_imported": "已导入的配置",
		"config_import_json": "导入 JSON 配置...",
		"config_reload_all": "重新加载全部",
		"config_extensions": "扩展",
		"config_ext_info": "使用 '导入 JSON 配置...' 来添加扩展文件。",
		"config_create_example": "创建示例扩展",
		"config_ext_hint": "在 toolkit_extensions/ 中创建文件，然后导入",
		"config_maintenance": "维护",
		"config_clear_cache": "清除缓存并重新初始化",
		"config_cancel": "取消",
		"config_save": "保存并关闭",
		"config_language": "语言",
		"config_status_error": "错误: ",
		"config_status_disabled": "已禁用",
		"config_status_commands": "%d 个命令",
		"config_enabled": "启用",
		"config_remove": "移除",
		"config_dlg_ext_exists_title": "扩展已存在",
		"config_dlg_ext_exists_msg": "Hello 扩展已存在于:\n%s\n\n如果想要重新创建，请先删除它。",
		"config_dlg_example_created_title": "示例扩展已创建并导入",
		"config_dlg_example_created_msg": "已创建并导入 Hello World 扩展！\n\n文件:\n• %s\n• %s\n\n试着在 Spotlight 中输入 '-hello'！",
		"config_dlg_clear_title": "清除已导入配置",
		"config_dlg_clear_msg": "这将移除所有已导入的 JSON 配置。\n\n注意：'toolkit_extensions/' 中的扩展和系统命令将保留。\n\n是否继续？",
		"tracker_add": "添加到 Spotlight 搜索",
		"tracker_remove": "从 Spotlight 搜索移除",
		"ctx_copy_path": "复制路径",
		"ctx_copy_name": "复制文件名",
		"ctx_show_in_fs": "在文件系统中显示",
		"ctx_open_folder": "打开所在文件夹",
		"ctx_open_external": "在外部编辑器打开",
		"ctx_pin": "置顶",
		"ctx_unpin": "取消置顶",
		"ctx_copy_node_path": "复制节点路径 ($...)",
		"ctx_copy_node_name": "复制节点名称",
		"ctx_focus_scene": "在场景树中定位",
		"ctx_duplicate": "复制节点",
		"cmd_new_res": "创建新资源...",
		"cmd_new_script": "创建 GDScript",
		"cmd_new_shader": "创建 Shader",
		"cmd_scene_ops": "场景操作",
		"cmd_reload_scene": "重载当前场景",
		"cmd_run_scene": "运行当前场景 (F6)",
		"cmd_save_scene": "保存当前场景",
		"cmd_color_utils": "颜色工具",
		"cmd_track_nodes": "搜索已追踪节点",
		"cmd_browse_nodes": "浏览引擎节点",
		"cmd_browse_class": "浏览类方法与属性",
		"cmd_filter_gd": "过滤: GDScript",
		"cmd_filter_scene": "过滤: 场景",
		"cmd_filter_img": "过滤: 图片",
		"cmd_filter_res": "过滤: 资源",
		"cmd_config": "配置",
		"cmd_open_settings": "打开插件设置",
		"cmd_reload_project": "重载项目",
		"cmd_quit_editor": "退出编辑器",
		"cmd_toggle_fullscreen": "切换全屏",
		"ui_toolbar_tooltip": "打开 Spotlight 设置",
		"ui_toolbar_btn": "Spotlight",
		"err_missing_action": "错误：配置中缺少 action_id",
		"cmd_requires": "需要：",
		"cmd_enter_filename": "输入文件名...",
		"cmd_create_prefix": "创建 ",
		"cmd_create_in": " 位于 ",
		"cmd_manual_open_settings": "打开设置",
		"cmd_manual_open_settings_desc": "打开项目设置 > Spotlight Search",
		"config_json_filter": "JSON 配置文件",
	}
}

static func initialize():
	if _initialized: return
	_initialized = true
	
	if ProjectSettings.has_setting(SETTING_LANGUAGE):
		_current_lang = ProjectSettings.get_setting(SETTING_LANGUAGE)
	else:
		_current_lang = "en"

static func register_settings():
	if not ProjectSettings.has_setting(SETTING_LANGUAGE):
		ProjectSettings.set_setting(SETTING_LANGUAGE, "en")
	ProjectSettings.set_initial_value(SETTING_LANGUAGE, "en")
	ProjectSettings.add_property_info({
		"name": SETTING_LANGUAGE,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "en,zh"
	})

static func get_current_language() -> String:
	initialize()
	return _current_lang

static func set_language(lang: String):
	if lang in TRANSLATIONS:
		_current_lang = lang
		ProjectSettings.set_setting(SETTING_LANGUAGE, lang)
		ProjectSettings.save()

static func get_string(key: String, format_args: Array = []) -> String:
	initialize()
	var dict = TRANSLATIONS.get(_current_lang, TRANSLATIONS["en"])
	var text = dict.get(key, key)
	
	if format_args.size() > 0:
		text = text % format_args
	
	return text

static func get_available_languages() -> Array:
	return ["en", "zh"]

static func get_language_name(code: String) -> String:
	match code:
		"en": return "English"
		"zh": return "中文"
		_: return code
