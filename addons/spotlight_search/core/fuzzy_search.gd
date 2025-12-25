@tool
# 模糊搜索工具类 (静态方法)
# 提供基于 Subsequence 的最优路径模糊匹配算法
class_name SpotlightFuzzySearch

const SCORE_MATCH = 10                  # 基础匹配分
const SCORE_CONSECUTIVE_BONUS = 5       # 连续匹配奖励
const SCORE_WORD_START_BONUS = 8        # 单词首字母/驼峰匹配奖励
const SCORE_GAP_PENALTY = -2            # 字符间隔惩罚
const SCORE_GAP_LEADING_PENALTY = -3    # 首个字符前的间隔惩罚 (更重，偏好前缀匹配)

# 缓存字符类型，加速判定
const CHAR_LOWER = 0
const CHAR_UPPER = 1
const CHAR_SEP = 2
const CHAR_OTHER = 3

# 模糊匹配
#
# 算法逻辑：
# 采用递归搜索寻找最佳匹配路径，而非简单的贪婪匹配。
# 例如：查询 "test" 匹配 "the_test"，贪婪算法可能会匹配首个 "t" 导致分数低，
# 而最优路径算法会匹配 "the_[test]" 从而获得连续匹配的高分。
#
# @param query: 查询字符串 (e.g. "mwin")
# @param text: 目标字符串 (e.g. "MainWindow.gd")
# @return: Dictionary {"score": int, "matched": bool}
static func fuzzy_match(query: String, text: String) -> Dictionary:
	if query.is_empty():
		return {"score": 0, "matched": true}
	
	if query.length() > text.length():
		return {"score": 0, "matched": false}
		
	# 预处理：统一转小写进行字符比较，保持原始 text 用于特征判断
	var query_lower = query.to_lower()
	var text_lower = text.to_lower()
	
	# 快速筛选：如果 query 的字符没有按顺序出现在 text 中，直接返回失败
	# (这一步是 O(N) 的贪婪检查，作为一种快速失败机制)
	if not _quick_check(query_lower, text_lower):
		return {"score": 0, "matched": false}
		
	# 核心递归计算最优分数
	var memo = {}
	var score = _recursive_match(
		query, text, query_lower, text_lower,
		0, 0, # q_idx, t_idx
		false, # is_consecutive
		memo
	)
	
	return {
		"score": score,
		"matched": (score > -999999) # 假设极小值代表失败
	}

# 快速检查子序列是否存在
static func _quick_check(q_lower: String, t_lower: String) -> bool:
	var q_len = q_lower.length()
	var t_len = t_lower.length()
	var qi = 0
	var ti = 0
	while qi < q_len and ti < t_len:
		if q_lower[qi] == t_lower[ti]:
			qi += 1
		ti += 1
	return qi == q_len

# 递归计算最高分
# 返回值：匹配分数，若无法匹配返回 -1000000 (极小值)
static func _recursive_match(
	query: String, text: String, q_lower: String, t_lower: String,
	q_idx: int, t_idx: int,
	last_consecutive: bool,
	memo: Dictionary
) -> int:
	
	# 1. 终止条件
	if q_idx == query.length():
		return 0 # 匹配完成
	if t_idx == text.length():
		return -1000000 # 文本耗尽，匹配失败
		
	# 2. 查表
	var key = (q_idx << 16) | t_idx # 简单的 key packing (假设文本长度不超过 65535)
	if last_consecutive: key = -key # 用负数区分 consec 状态
	
	if memo.has(key):
		return memo[key]
		
	# 3. 搜索逻辑
	var char_q = q_lower[q_idx]
	var max_score = -1000000
	
	# 在 text 中寻找 char_q 的所有后续出现位置
	# 限制搜索范围：如果剩下的 text 长度小于剩下的 query 长度，则不可能匹配
	var limit = text.length() - (query.length() - q_idx) + 1
	
	for i in range(t_idx, limit):
		if t_lower[i] == char_q:
			# --- 计算当前字符匹配的分数 ---
			var current_score = SCORE_MATCH
			var is_consecutive = (i == t_idx) and last_consecutive
			
			# 奖励机制
			if is_consecutive:
				current_score += SCORE_CONSECUTIVE_BONUS
			
			# 单词首字母/特征奖励
			if _is_word_start(text, i):
				current_score += SCORE_WORD_START_BONUS
				
			# 惩罚机制 (Gap Penalty)
			var gap = i - t_idx
			if gap > 0:
				if q_idx == 0:
					# 首个字符前的 gap 惩罚更重
					current_score += gap * SCORE_GAP_LEADING_PENALTY
				else:
					current_score += gap * SCORE_GAP_PENALTY
			
			# --- 递归匹配剩余部分 ---
			var rest_score = _recursive_match(
				query, text, q_lower, t_lower,
				q_idx + 1, i + 1,
				true, # 下一个字符紧接着当前字符算 consecutive
				memo
			)
			
			if rest_score > -1000000:
				var total = current_score + rest_score
				if total > max_score:
					max_score = total
	
	# 4. 记录并返回
	memo[key] = max_score
	return max_score

# 判断是否是单词开头
static func _is_word_start(text: String, idx: int) -> bool:
	if idx == 0: return true
	
	var char_cur = text[idx]
	var char_prev = text[idx - 1]
	
	# 1. 前一个是分隔符
	if char_prev in ["_", "-", ".", " ", "/"]:
		return true
		
	# 2. CamelCase: 如果当前是大写，且前一个是小写
	# 注意：Unicode 兼容性
	if char_cur != char_cur.to_lower() and char_prev == char_prev.to_lower():
		return true
		
	return false

	
