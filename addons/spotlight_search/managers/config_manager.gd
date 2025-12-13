@tool
extends RefCounted

const TranslationService = preload("res://addons/spotlight_search/services/translation_service.gd")

const SETTING_MAX_RESULTS = "addons/spotlight_search/config/max_results"
const SETTING_EXCLUDE_FOLDERS = "addons/spotlight_search/config/exclude_folders"
const SETTING_EXTERNAL_CONFIGS = "addons/spotlight_search/config/external_configs"

static func register_settings():
	TranslationService.register_settings()
	
	if not ProjectSettings.has_setting(SETTING_MAX_RESULTS):
		ProjectSettings.set_setting(SETTING_MAX_RESULTS, 20)
	ProjectSettings.set_initial_value(SETTING_MAX_RESULTS, 20)
	ProjectSettings.add_property_info({
		"name": SETTING_MAX_RESULTS,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,100"
	})
	
	if not ProjectSettings.has_setting(SETTING_EXCLUDE_FOLDERS):
		ProjectSettings.set_setting(SETTING_EXCLUDE_FOLDERS, PackedStringArray(["addons/", ".git/", ".import/", ".godot/"]))
	ProjectSettings.set_initial_value(SETTING_EXCLUDE_FOLDERS, PackedStringArray(["addons/", ".git/", ".import/", ".godot/"]))
	ProjectSettings.add_property_info({
		"name": SETTING_EXCLUDE_FOLDERS,
		"type": TYPE_PACKED_STRING_ARRAY
	})
	
	if ProjectSettings.has_setting(SETTING_EXTERNAL_CONFIGS):
		var current = ProjectSettings.get_setting(SETTING_EXTERNAL_CONFIGS)
		if current is PackedStringArray or current is Array:
			var new_dict = {}
			for path in current:
				new_dict[path] = { "enabled": true }
			ProjectSettings.set_setting(SETTING_EXTERNAL_CONFIGS, new_dict)
			ProjectSettings.save()
	
	if not ProjectSettings.has_setting(SETTING_EXTERNAL_CONFIGS):
		ProjectSettings.set_setting(SETTING_EXTERNAL_CONFIGS, {})
	
	ProjectSettings.set_initial_value(SETTING_EXTERNAL_CONFIGS, {})
	ProjectSettings.add_property_info({
		"name": SETTING_EXTERNAL_CONFIGS,
		"type": TYPE_DICTIONARY
	})
	
	var shortcut_key_setting = "addons/spotlight_search/config/shortcut_keycode"
	if not ProjectSettings.has_setting(shortcut_key_setting):
		ProjectSettings.set_setting(shortcut_key_setting, KEY_Q)
	ProjectSettings.add_property_info({
		"name": shortcut_key_setting,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_NONE
	})
	
	var shortcut_alt = "addons/spotlight_search/config/shortcut_use_alt"
	if not ProjectSettings.has_setting(shortcut_alt):
		ProjectSettings.set_setting(shortcut_alt, true)
	ProjectSettings.add_property_info({
		"name": shortcut_alt,
		"type": TYPE_BOOL
	})
	
	var shortcut_ctrl = "addons/spotlight_search/config/shortcut_use_ctrl"
	if not ProjectSettings.has_setting(shortcut_ctrl):
		ProjectSettings.set_setting(shortcut_ctrl, false)
	ProjectSettings.add_property_info({
		"name": shortcut_ctrl,
		"type": TYPE_BOOL
	})
	
	var shortcut_shift = "addons/spotlight_search/config/shortcut_use_shift"
	if not ProjectSettings.has_setting(shortcut_shift):
		ProjectSettings.set_setting(shortcut_shift, false)
	ProjectSettings.add_property_info({
		"name": shortcut_shift,
		"type": TYPE_BOOL
	})

	ProjectSettings.save()

static func get_max_results() -> int:
	return ProjectSettings.get_setting(SETTING_MAX_RESULTS, 20)

static func get_exclude_patterns() -> PackedStringArray:
	return ProjectSettings.get_setting(SETTING_EXCLUDE_FOLDERS, PackedStringArray(["addons/", ".git/", ".import/", ".godot/"]))

# Returns Dictionary: { "res://path/to/config.json": { "enabled": true } }
static func get_external_configs() -> Dictionary:
	var val = ProjectSettings.get_setting(SETTING_EXTERNAL_CONFIGS, {})
	if val is Dictionary:
		return val
	return {}

static func add_external_config(path: String):
	var current = get_external_configs().duplicate()
	if not current.has(path):
		current[path] = { "enabled": true }
		ProjectSettings.set_setting(SETTING_EXTERNAL_CONFIGS, current)
		ProjectSettings.save()

static func remove_external_config(path: String):
	# Simply remove the reference from external configs
	# The actual file is not deleted, just the reference
	var current = get_external_configs().duplicate()
	if current.has(path):
		current.erase(path)
		ProjectSettings.set_setting(SETTING_EXTERNAL_CONFIGS, current)
		ProjectSettings.save()

static func set_external_config_enabled(path: String, enabled: bool):
	var current = get_external_configs().duplicate()
	if not current.has(path):
		current[path] = {}

	current[path]["enabled"] = enabled
	ProjectSettings.set_setting(SETTING_EXTERNAL_CONFIGS, current)
	ProjectSettings.save()

static func clear_all_external_configs():
	# Clear all external configs from ProjectSettings
	ProjectSettings.set_setting(SETTING_EXTERNAL_CONFIGS, {})
	ProjectSettings.save()

static func is_shortcut(event: InputEventKey) -> bool:
	if not event.pressed or event.echo: return false
	
	var key = ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_keycode", KEY_Q)
	var use_alt = ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_use_alt", true)
	var use_ctrl = ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_use_ctrl", false)
	var use_shift = ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_use_shift", false)
	
	if event.keycode != key: return false
	if event.alt_pressed != use_alt: return false
	if event.ctrl_pressed != use_ctrl: return false
	if event.shift_pressed != use_shift: return false
	
	return true

static func set_max_results(value: int):
	ProjectSettings.set_setting(SETTING_MAX_RESULTS, value)
	ProjectSettings.save()

static func set_exclude_patterns(value: PackedStringArray):
	ProjectSettings.set_setting(SETTING_EXCLUDE_FOLDERS, value)
	ProjectSettings.save()

static func set_shortcut(key: int, alt: bool, ctrl: bool, shift: bool):
	ProjectSettings.set_setting("addons/spotlight_search/config/shortcut_keycode", key)
	ProjectSettings.set_setting("addons/spotlight_search/config/shortcut_use_alt", alt)
	ProjectSettings.set_setting("addons/spotlight_search/config/shortcut_use_ctrl", ctrl)
	ProjectSettings.set_setting("addons/spotlight_search/config/shortcut_use_shift", shift)
	ProjectSettings.save()

static func get_shortcut_config() -> Dictionary:
	return {
		"keycode": ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_keycode", KEY_Q),
		"alt": ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_use_alt", true),
		"ctrl": ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_use_ctrl", false),
		"shift": ProjectSettings.get_setting("addons/spotlight_search/config/shortcut_use_shift", false)
	}
