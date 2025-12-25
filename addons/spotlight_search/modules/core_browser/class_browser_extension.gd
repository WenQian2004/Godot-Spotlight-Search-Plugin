@tool
extends SpotlightExtension

# 动态加载引用
var CLASS_RESULT_SCRIPT
var FUZZY_SEARCH
const SCORE_BASE = 100

func _init():
	var base_dir = get_script().resource_path.get_base_dir()
	CLASS_RESULT_SCRIPT = load(base_dir + "/class_result.gd")
	FUZZY_SEARCH = load("res://addons/spotlight_search/core/fuzzy_search.gd")

func get_id() -> String:
	return "core.browser"

func get_display_name() -> String:
	return "Class Browser"

func get_author() -> String:
	return "Godot Engine"

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = text.strip_edges().to_lower()
	
	# Determine mode based on context or text prefix
	var mode = "" # "node" or "class" or "class_members"
	var target_class = ""
	
	# 1. 检查上下文 (Context-based navigation)
	if not context.is_empty():
		var last = context.back()
		var uid = last.get_unique_id()
		
		if uid == "cmd.node":
			mode = "node"
		elif uid.begins_with("class."):
			# Context like "class.Button" -> Show members
			mode = "class_members"
			target_class = last.class_name_str
	
	# 2. 检查前缀 (Direct string query)
	# 只有当没有特定上下文，或者正在根上下文时才检查前缀
	if mode == "" and context.is_empty():
		if text.begins_with("-node"):
			mode = "node"
			# Remove prefix from search term
			var parts = text.split(" ", false, 1)
			if parts.size() > 1:
				search_term = parts[1].to_lower()
			else:
				search_term = "" # List all
	
	# 执行查询
	if mode == "node":
		results = _query_classes(search_term, true)
	elif mode == "class_members" and target_class != "":
		results = _query_members(target_class, search_term)
		
	return results

# 查询类列表 (Node模式只显示 Node 子类)
func _query_classes(query: String, only_nodes: bool) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var class_list = ClassDB.get_class_list()
	
	for c_name in class_list:
		if c_name.begins_with("_"): continue # Skip internal
		
		# Filter nodes
		if only_nodes and not ClassDB.is_parent_class(c_name, "Node"):
			continue
			
		var score = 0
		if query.is_empty():
			score = SCORE_BASE # Default score
		else:
			var match_res = FUZZY_SEARCH.fuzzy_match(query, c_name)
			if not match_res.matched:
				continue
			score = match_res.score
		
		# 构造 Result
		var item = CLASS_RESULT_SCRIPT.new(c_name, "", CLASS_RESULT_SCRIPT.MemberType.CLASS, "")
		item.score = score
		
		# 填充额外信息 (父类)
		item.parent_class = ClassDB.get_parent_class(c_name)
		
		# 为 Node 模式添加特定标签
		item.tags = ["Class"]
		if only_nodes:
			item.tags.append("Node")
			
		results.append(item)
	
	# 排序
	results.sort_custom(func(a, b): return a.score > b.score)
	
	# 限制数量，防止卡顿
	if results.size() > 100:
		results.resize(100)
		
	return results

# 查询类的成员 (属性/方法)
func _query_members(cls_name: String, query: String) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	
	# 1. Properties
	var props = ClassDB.class_get_property_list(cls_name)
	for p in props:
		var usage = p["usage"]
		# 只显示编辑器可见的属性
		if not (usage & PROPERTY_USAGE_EDITOR) and not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var p_name = p["name"]
		
		var score = 0
		if query.is_empty():
			score = SCORE_BASE
		else:
			var match_res = FUZZY_SEARCH.fuzzy_match(query, p_name)
			if not match_res.matched:
				continue
			score = match_res.score
			
		var item = CLASS_RESULT_SCRIPT.new(cls_name, p_name, CLASS_RESULT_SCRIPT.MemberType.PROPERTY, "")
		item.return_type = _type_to_string(p["type"])
		item.score = score
		results.append(item)
		
	# 3. Methods
	var methods = ClassDB.class_get_method_list(cls_name)
	for m in methods:
		var m_name = m["name"]
		if m_name.begins_with("_"): continue
		
		var score = 0
		if query.is_empty():
			score = SCORE_BASE
		else:
			var match_res = FUZZY_SEARCH.fuzzy_match(query, m_name)
			if not match_res.matched:
				continue
			score = match_res.score
			
		var item = CLASS_RESULT_SCRIPT.new(cls_name, m_name, CLASS_RESULT_SCRIPT.MemberType.METHOD, "")
		item.return_type = _type_to_string(m.get("return", {}).get("type", 0))
		
		# Build signature
		var args = m.get("args", [])
		var arg_strs = []
		for a in args:
			arg_strs.append(a["name"] + ": " + _type_to_string(a["type"]))
		item.signature = m_name + "(" + ", ".join(arg_strs) + ")"
		
		item.score = score
		results.append(item)
		
	# 4. Signals
	var signals = ClassDB.class_get_signal_list(cls_name)
	for s in signals:
		var s_name = s["name"]
		
		var score = 0
		if query.is_empty():
			score = SCORE_BASE
		else:
			var match_res = FUZZY_SEARCH.fuzzy_match(query, s_name)
			if not match_res.matched:
				continue
			score = match_res.score
			
		var item = CLASS_RESULT_SCRIPT.new(cls_name, s_name, CLASS_RESULT_SCRIPT.MemberType.SIGNAL, "")
		item.score = score
		results.append(item)
		
	# 排序
	results.sort_custom(func(a, b): return a.score > b.score)
	
	if results.size() > 200:
		results.resize(200)
		
	return results

func _type_to_string(type: int) -> String:
	match type:
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_RECT2: return "Rect2"
		TYPE_VECTOR4: return "Vector4"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_COLOR: return "Color"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT: return "Object"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return "Variant"
