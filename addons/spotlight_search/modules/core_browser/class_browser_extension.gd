@tool
extends SpotlightSimpleExtension

# --- 类浏览器扩展 (Refactored) ---

# 动态加载引用
const ClassResultScript = preload("res://addons/spotlight_search/modules/core_browser/class_result.gd")

func _init():
	# 注册 -node 指令
	add_command("-node", "Browse Engine Nodes") \
		.set_icon("Node") \
		.set_tags(["Official", "Command"]) \
		.set_dynamic_provider(_provide_node_classes)
		
	# 注册 -class 指令 (浏览所有类)
	add_command("-class", "Browse All Engine Classes") \
		.set_icon("Object") \
		.set_tags(["Official", "Command"]) \
		.set_dynamic_provider(_provide_all_classes)

func get_id() -> String:
	return "core.browser"

func get_display_name() -> String:
	return "Class Browser"

func get_author() -> String:
	return "Godot Engine"

# --- 核心查询逻辑重写 ---

func query(text: String, context: Array) -> Array[SpotlightResultItem]:
	# 1. 检查是否处于 "class." 上下文中 (查看类成员)
	if not context.is_empty():
		var last = context.back()
		var uid = last.get_unique_id()
		
		if uid.begins_with("class.") and not uid.contains(".member."):
			# Context like "class.Button" -> Show members
			# uid format: "class.Button"
			var class_name_str = uid.trim_prefix("class.")
			return _provide_members(class_name_str, text)
			
	# 2. 否则使用基类逻辑 (处理 -node, -class 等)
	return super.query(text, context)

# --- Providers ---

func _provide_node_classes(query: String) -> Array[SpotlightResultItem]:
	return _query_classes(query, true)

func _provide_all_classes(query: String) -> Array[SpotlightResultItem]:
	return _query_classes(query, false)

func _query_classes(query: String, only_nodes: bool) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var class_list = ClassDB.get_class_list()
	var search_term = query.to_lower()
	
	for c_name in class_list:
		if c_name.begins_with("_"): continue # Skip internal
		
		# Filter nodes
		if only_nodes and not ClassDB.is_parent_class(c_name, "Node"):
			continue
			
		var score = 0
		if search_term.is_empty():
			score = 100
		else:
			var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, c_name)
			if not match_res.matched:
				continue
			score = match_res.score
		
		# 构造 Result
		var item = ClassResultScript.new(c_name, "", ClassResultScript.MemberType.CLASS, "")
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
	
	# 限制数量
	if results.size() > 100:
		results.resize(100)
		
	return results

func _provide_members(cls_name: String, query: String) -> Array[SpotlightResultItem]:
	var results: Array[SpotlightResultItem] = []
	var search_term = query.to_lower()
	
	# 1. Properties
	var props = ClassDB.class_get_property_list(cls_name)
	for p in props:
		var usage = p["usage"]
		# 只显示编辑器可见的属性
		if not (usage & PROPERTY_USAGE_EDITOR) and not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var p_name = p["name"]
		
		var score = 0
		if search_term.is_empty():
			score = 100
		else:
			var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, p_name)
			if not match_res.matched:
				continue
			score = match_res.score
			
		var item = ClassResultScript.new(cls_name, p_name, ClassResultScript.MemberType.PROPERTY, "")
		item.return_type = _type_to_string(p["type"])
		item.score = score
		results.append(item)
		
	# 2. Methods
	var methods = ClassDB.class_get_method_list(cls_name)
	for m in methods:
		var m_name = m["name"]
		if m_name.begins_with("_"): continue
		
		var score = 0
		if search_term.is_empty():
			score = 100
		else:
			var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, m_name)
			if not match_res.matched:
				continue
			score = match_res.score
			
		var item = ClassResultScript.new(cls_name, m_name, ClassResultScript.MemberType.METHOD, "")
		item.return_type = _type_to_string(m.get("return", {}).get("type", 0))
		
		# Build signature
		var args = m.get("args", [])
		var arg_strs = []
		for a in args:
			arg_strs.append(a["name"] + ": " + _type_to_string(a["type"]))
		item.signature = m_name + "(" + ", ".join(arg_strs) + ")"
		
		item.score = score
		results.append(item)
		
	# 3. Signals
	var signals = ClassDB.class_get_signal_list(cls_name)
	for s in signals:
		var s_name = s["name"]
		
		var score = 0
		if search_term.is_empty():
			score = 100
		else:
			var match_res = SpotlightFuzzySearch.fuzzy_match(search_term, s_name)
			if not match_res.matched:
				continue
			score = match_res.score
			
		var item = ClassResultScript.new(cls_name, s_name, ClassResultScript.MemberType.SIGNAL, "")
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
