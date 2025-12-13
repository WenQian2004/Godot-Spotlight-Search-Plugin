@tool
extends RefCounted

## Hello Extension Actions
## This script handles all actions for the Hello World extension.
## Each method receives an Array of arguments as defined in args_def.

const ToolkitAPI = preload("res://addons/spotlight_search/api/toolkit_api.gd")

static func hello_world(args: Array) -> void:
	print("[Hello] Hello, World!")
	ToolkitAPI.show_toast("Hello, World! 👋", "success")

static func greet_simple(args: Array) -> void:
	var name = args[0] if args.size() > 0 else "Friend"
	var message = "Hello, %s!" % name
	print("[Hello] " + message)
	ToolkitAPI.show_toast(message, "success")

static func greet_formal(args: Array) -> void:
	var title = args[0] if args.size() > 0 else "Mr"
	var name = args[1] if args.size() > 1 else "Unknown"
	var message = "Good day, %s. %s. How may I assist you?" % [title, name]
	print("[Hello] " + message)
	ToolkitAPI.show_toast(message, "success")

static func greet_count(args: Array) -> void:
	var name = args[0] if args.size() > 0 else "Friend"
	var count = int(args[1]) if args.size() > 1 else 1
	count = clamp(count, 1, 10)  # Limit to prevent spam
	
	for i in range(count):
		print("[Hello] (%d/%d) Hello, %s!" % [i + 1, count, name])
	
	ToolkitAPI.show_toast("Greeted %s %d times!" % [name, count], "success")

static func calc_add(args: Array) -> void:
	var a = float(args[0]) if args.size() > 0 else 0.0
	var b = float(args[1]) if args.size() > 1 else 0.0
	var result = a + b
	var message = "%.2f + %.2f = %.2f" % [a, b, result]
	print("[Hello Calc] " + message)
	
	# Copy result to clipboard
	DisplayServer.clipboard_set(str(result))
	ToolkitAPI.show_toast(message + " (copied!)", "success")

static func calc_multiply(args: Array) -> void:
	var a = float(args[0]) if args.size() > 0 else 0.0
	var b = float(args[1]) if args.size() > 1 else 0.0
	var result = a * b
	var message = "%.2f × %.2f = %.2f" % [a, b, result]
	print("[Hello Calc] " + message)
	
	DisplayServer.clipboard_set(str(result))
	ToolkitAPI.show_toast(message + " (copied!)", "success")

static func show_time(args: Array) -> void:
	var dt = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]
	print("[Hello] Current time: " + time_str)
	
	DisplayServer.clipboard_set(time_str)
	ToolkitAPI.show_toast("📅 " + time_str + " (copied!)", "success")
