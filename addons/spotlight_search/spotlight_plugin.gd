@tool
extends EditorPlugin

const MANAGER_NAME = "SpotlightManager"

var main_window_instance: PopupPanel
var base_path: String
func _enter_tree() -> void:
	# 动态获取插件根目录
	base_path = get_script().resource_path.get_base_dir()
	
	# 添加单例 (Autoload)
	add_autoload_singleton(MANAGER_NAME, base_path + "/core/spotlight_manager.gd")
	add_autoload_singleton("SpotlightInput", base_path + "/core/input_manager.gd")
	
	
	# 添加工具菜单项
	add_tool_menu_item("Spotlight Settings", _open_settings)
	add_tool_menu_item("Spotlight: 清理缓存并重载", _clear_cache_and_reload)

	add_tool_menu_item("Spotlight: 重新扫描文件", _rescan_files)
	
	# 注册默认设置到 Project Settings
	SpotlightConfig.register_settings()
	
	print("[Spotlight] Plugin Loaded from: " + base_path)
	
	# 1. 实例化主窗口
	_create_main_window()
	
	# 2. 注册 Inspector Tracker (如果存在)
	_register_tracker()
	
	# 通过重写 _unhandled_input 等方法实现全局快捷键监听
	_add_custom_shortcut()

func _create_main_window():
	if main_window_instance:
		main_window_instance.queue_free()
	
	var window_scene_path = base_path + "/ui/components/main_window/main_window.tscn"
	main_window_instance = load(window_scene_path).instantiate()
	main_window_instance.visible = false
	EditorInterface.get_base_control().add_child(main_window_instance)

var tracker_instance
func _register_tracker():
	var tracker_path = base_path + "/modules/core_track/spotlight_tracker.gd"
	if FileAccess.file_exists(tracker_path):
		var script = load(tracker_path)
		if script:
			tracker_instance = script.new()
			add_inspector_plugin(tracker_instance)
			print("[Spotlight] Inspector Tracker Registered")

func _exit_tree() -> void:
	# 移除单例
	remove_autoload_singleton(MANAGER_NAME)
	remove_autoload_singleton("SpotlightInput")
	
	if tracker_instance:
		remove_inspector_plugin(tracker_instance)
		tracker_instance = null
	
	# 移除工具菜单项
	remove_tool_menu_item("Spotlight Settings")
	remove_tool_menu_item("Spotlight: 清理缓存并重载")
	remove_tool_menu_item("Spotlight: 重新扫描文件")
	
	print("[Spotlight] Plugin Unloaded")
	
	# 清理窗口
	if main_window_instance:
		main_window_instance.queue_free()
		
	_remove_custom_shortcut()

# --- 快捷键处理 (使用 unhandled_input 确保全局捕获) ---
func _match_shortcut(event: InputEventKey) -> bool:
	var shortcut = SpotlightConfig.get_shortcut()
	if shortcut.is_empty(): return false
	
	if event.keycode != shortcut.get("keycode", 0): return false
	if event.ctrl_pressed != shortcut.get("ctrl_pressed", false): return false
	if event.shift_pressed != shortcut.get("shift_pressed", false): return false
	if event.alt_pressed != shortcut.get("alt_pressed", false): return false
	if event.meta_pressed != shortcut.get("meta_pressed", false): return false
	
	return true

func _unhandled_input(event):
	# 全局监听快捷键 - 即使没有焦点也能触发
	if event is InputEventKey and event.pressed and not event.echo:
		if _match_shortcut(event):
			if main_window_instance:
				main_window_instance.open_spotlight()
				get_viewport().set_input_as_handled()

# 重写此方法以确保在编辑器的任何地方都能捕获输入
func _handles(object):
	return true

func _forward_canvas_gui_input(event):
	# 在 2D 编辑器中也能捕获快捷键
	if event is InputEventKey and event.pressed and not event.echo:
		if _match_shortcut(event):
			if main_window_instance:
				main_window_instance.open_spotlight()
			return true
	return false

func _forward_3d_gui_input(camera, event):
	# 在 3D 编辑器中也能捕获快捷键
	if event is InputEventKey and event.pressed and not event.echo:
		if _match_shortcut(event):
			if main_window_instance:
				main_window_instance.open_spotlight()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _add_custom_shortcut():
	# 预留接口：用于后续实现更深度的 Shortcut 集成
	pass

func _remove_custom_shortcut():
	pass

var settings_window_instance: Window = null

func _open_settings():
	if settings_window_instance and is_instance_valid(settings_window_instance):
		settings_window_instance.grab_focus()
		settings_window_instance.popup_centered() # 重新居中
		return

	var SettingsPanel = load(base_path + "/ui/settings_panel/settings_panel.gd")
	settings_window_instance = SettingsPanel.new()
	EditorInterface.get_base_control().add_child(settings_window_instance)
	settings_window_instance.popup_centered()

func _clear_cache_and_reload():
	print("[Spotlight] 清理缓存并重载...")
	
	# 1. 重新创建主窗口
	_create_main_window()
	
	# 2. 触发文件重新扫描
	_rescan_files()
	
	print("[Spotlight] 重载完成！")


func _rescan_files():
	print("[Spotlight] 重新扫描文件...")
	var manager = get_node_or_null("/root/SpotlightManager")
	if manager:
		# 触发所有扩展重新扫描
		for ext in manager.get_all_extensions():
			if ext.has_method("_on_enable"):
				ext._on_enable()
	print("[Spotlight] 扫描完成！")
