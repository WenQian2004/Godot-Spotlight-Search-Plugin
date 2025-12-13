extends RefCounted

enum Type { 
	FILE, SCENE, SCRIPT, IMAGE, SHADER, AUDIO, RESOURCE, 
	COMMAND, CREATE_ACTION, NODE, ACTION, PROPERTY, METHOD
}

var file_name: String
var file_path: String
var type: Type
var score: int = 0
var desc: String = ""
var command_name: String = ""
var icon_name: String = ""
var args: Array = []
var is_container: bool = false

static func get_type_from_path(path: String) -> Type:
	if path.ends_with(".tscn") or path.ends_with(".scn"): return Type.SCENE
	if path.ends_with(".gd") or path.ends_with(".cs"): return Type.SCRIPT
	if path.ends_with(".png") or path.ends_with(".jpg") or path.ends_with(".svg") or path.ends_with(".webp"): return Type.IMAGE
	if path.ends_with(".gdshader"): return Type.SHADER
	if path.ends_with(".tres") or path.ends_with(".res"): return Type.RESOURCE
	if path.ends_with(".wav") or path.ends_with(".ogg") or path.ends_with(".mp3"): return Type.AUDIO
	return Type.FILE

static func get_icon_name(t: Type) -> String:
	match t:
		Type.SCENE: return "PackedScene"
		Type.SCRIPT: return "Script"
		Type.IMAGE: return "TextureRect"
		Type.SHADER: return "Shader"
		Type.AUDIO: return "AudioStreamPlayer"
		Type.RESOURCE: return "ResourcePreloader"
		Type.COMMAND: return "Console"
		Type.CREATE_ACTION: return "Add"
		Type.ACTION: return "Tools"
		Type.NODE: return "Node"
		_: return "File"
