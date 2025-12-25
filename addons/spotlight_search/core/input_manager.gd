@tool
extends Node

# 动作名称常量
const ACT_NAV_UP = "nav_up"
const ACT_NAV_DOWN = "nav_down"
const ACT_EXECUTE = "execute"     # Enter
const ACT_NAV_IN = "nav_in"       # Tab / Enter(Folder)
const ACT_NAV_BACK = "nav_back"   # Esc
const ACT_PANEL_TOGGLE = "panel_toggle" # Right Arrow
const ACT_PANEL_CLOSE = "panel_close"   # Left Arrow
const ACT_FAV_TOGGLE = "fav_toggle"     # Shift + Up
const ACT_SHOW_FAVS = "show_favs"       # Shift + Down

# 默认键位映射
static var _key_map = {
	ACT_NAV_UP: [KEY_UP],
	ACT_NAV_DOWN: [KEY_DOWN],
	ACT_EXECUTE: [KEY_ENTER, KEY_KP_ENTER],
	ACT_NAV_IN: [KEY_TAB],
	ACT_NAV_BACK: [KEY_ESCAPE],
	ACT_PANEL_TOGGLE: [KEY_RIGHT],
	ACT_PANEL_CLOSE: [KEY_LEFT],
	ACT_FAV_TOGGLE: [KEY_UP], # 特殊处理：Shift 在逻辑中判断
	ACT_SHOW_FAVS: [KEY_DOWN] # 特殊处理：Shift 在逻辑中判断
}

# 检查事件是否匹配动作
static func is_action(event: InputEvent, action: String) -> bool:
	if not event is InputEventKey or not event.pressed:
		return false
		
	if not _key_map.has(action):
		return false
		
	var valid_keys = _key_map[action]
	
	# 1. 匹配 KeyCode
	if event.keycode not in valid_keys:
		return false
		
	# 2. 匹配修饰键 (Shift/Ctrl/Alt)
	# TODO:当前采用基础的修饰键检查逻辑，未来可支持更灵活的 InputMap 映射配置
	match action:
		ACT_FAV_TOGGLE:
			return event.shift_pressed # 必须按 Shift
		ACT_SHOW_FAVS:
			return event.shift_pressed # 必须按 Shift
		_:
			# 其他导航键通常不按 Shift (除非你希望 Shift+Down 也能向下)
			if action == ACT_NAV_UP or action == ACT_NAV_DOWN:
				return not event.shift_pressed
			return true

	return true
