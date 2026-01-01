@tool
extends "res://addons/spotlight_search/core/spotlight_simple_extension.gd"

# --- 重构后的 SayHello 示例 ---

func _init():
	# 1. 顶层命令 -hello
	var hello = add_command("-hello", "WenQian's greeting commands") \
		.set_description("Demo extension for greeting commands.") \
		.set_icon("Node") \
		.set_tags(["WenQian", "Community"])
		
	# 2. 子命令 -greet
	hello.add_command("greet", "Print a friendly greeting message") \
		.set_description("Prints 'Hello from WenQian!' to console.") \
		.set_icon("Popup") \
		.set_action(func(): print("Hello from WenQian! 👋")) \
		.set_tags(["WenQian", "Action"])
		
	# 3. 子命令 -say (带自定义预览)
	# 这里的 hello_preview.tscn 是一个场景，我们需要将其包装成 Control
	# 由于 SimpleExtension 的 set_preview_factory 需要返回 Control
	# 我们可以直接实例化场景
	var preview_scene = load("res://addons/spotlight_search/examples/say_hello/hello_preview.tscn")
	
	hello.add_command("say", "Say something with custom input") \
		.set_description("Open a custom UI to say something.") \
		.set_icon("TextEdit") \
		.set_preview_factory(func(): return preview_scene.instantiate()) \
		.set_tags(["WenQian", "Interactive"])
		
	# 4. 嵌套命令 -nested
	var nested = hello.add_command("nested", "Demonstrate deeper nesting") \
		.set_description("Explore multi-level command nesting.") \
		.set_icon("Tree") \
		.set_tags(["WenQian", "Category"])
		
	nested.add_command("deep1", "A deeply nested action") \
		.set_description("Level 3 nested command example 1.") \
		.set_icon("AudioListener2D") \
		.set_action(func(): print("Deep action executed!"))
		
	nested.add_command("deep2", "Another deeply nested command") \
		.set_description("Level 3 nested command example 2.") \
		.set_icon("Animation") \
		.set_action(func(): print("Another deep action!"))

func get_id() -> String:
	return "wenqian.hello"

func get_display_name() -> String:
	return "WenQian Hello"

func get_author() -> String:
	return "WenQian"

func get_version() -> String:
	return "1.0.0"
