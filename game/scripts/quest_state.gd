class_name ValleyQuest
extends RefCounted

signal changed
const VERSION := 1
const LETTERS := ["cedar", "river", "star"]
const PEOPLE := ["杉婆婆", "渡口的阿澄", "观星台的陆先生"]
var letters: Array[String] = []
var delivered: Array[String] = []
var lamps: Array[int] = []
var mirror_turn := 0
var solved := false
var finished := false
var elapsed := 0.0

func light_lamp(id: int) -> bool:
	if id < 0 or id > 2 or lamps.has(id):
		return false
	lamps.append(id)
	check_beam()
	changed.emit()
	return true

func turn_mirror() -> bool:
	mirror_turn = (mirror_turn + 1) % 4
	var was_solved := solved
	check_beam()
	changed.emit()
	return solved and not was_solved

func check_beam() -> void:
	if lamps.has(2) and mirror_turn == 2:
		solved = true

func collect(id: String) -> bool:
	if not LETTERS.has(id) or letters.has(id) or delivered.has(id):
		return false
	if id == "star" and not solved:
		return false
	letters.append(id)
	changed.emit()
	return true

func deliver(id: String) -> bool:
	if not letters.has(id) or delivered.has(id):
		return false
	letters.erase(id)
	delivered.append(id)
	changed.emit()
	return true

func return_to_post() -> bool:
	if delivered.size() != 3 or finished:
		return false
	finished = true
	changed.emit()
	return true

func to_data(player_position: Vector2) -> Dictionary:
	return {"version": VERSION, "letters": letters.duplicate(), "delivered": delivered.duplicate(),
		"lamps": lamps.duplicate(), "mirror_turn": mirror_turn, "solved": solved,
		"finished": finished, "elapsed": elapsed, "position": [player_position.x, player_position.y]}

static func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func save_issue(data: Variant) -> String:
	# Validate the whole on-disk envelope before permissive recovery can discard
	# anything. Unknown versions/fields belong to their writer, not this version.
	if not data is Dictionary:
		return "存档不是完整的记录对象。"
	var keys := ["version", "letters", "delivered", "lamps", "mirror_turn", "solved", "finished", "elapsed", "position"]
	if not finite_number(data.get("version")) or data.version != VERSION:
		return "这份存档的版本暂不支持。"
	if data.size() != keys.size() or not data.has_all(keys):
		return "存档字段缺失或含有当前版本不认识的内容。"
	for key in ["letters", "delivered"]:
		if not data[key] is Array or data[key].size() > LETTERS.size():
			return "信件记录不完整。"
		var seen: Array = []
		for id in data[key]:
			if not id is String or not LETTERS.has(id) or seen.has(id):
				return "信件记录包含无法识别或重复的内容。"
			seen.append(id)
	for id in data.letters:
		if data.delivered.has(id):
			return "邮袋与送达记录互相冲突。"
	if not data.lamps is Array or data.lamps.size() > 3:
		return "路灯记录不完整。"
	var lamps_seen: Array = []
	for id in data.lamps:
		if not finite_number(id) or float(id) != floorf(float(id)) or id < 0 or id > 2 or lamps_seen.has(int(id)):
			return "路灯记录包含无法识别或重复的内容。"
		lamps_seen.append(int(id))
	if not finite_number(data.mirror_turn) or float(data.mirror_turn) != floorf(float(data.mirror_turn)) or data.mirror_turn < 0 or data.mirror_turn > 3:
		return "镜面方向记录无法识别。"
	if not data.solved is bool or not data.finished is bool:
		return "邮路完成状态无法识别。"
	if (data.letters.has("star") or data.delivered.has("star")) and not data.solved:
		return "银戳信与光路记录互相冲突。"
	if (data.solved and not lamps_seen.has(2)) or (lamps_seen.has(2) and data.mirror_turn == 2 and not data.solved):
		return "灯镜解谜记录互相冲突。"
	if data.finished and data.delivered.size() != LETTERS.size():
		return "邮路结尾与送达记录互相冲突。"
	if not finite_number(data.elapsed) or data.elapsed < 0:
		return "游玩时间记录无法识别。"
	if not data.position is Array or data.position.size() != 2 or not finite_number(data.position[0]) or not finite_number(data.position[1]):
		return "位置记录不完整。"
	return ""

func restore_checked(data: Variant) -> Dictionary:
	var issue := save_issue(data)
	if not issue.is_empty():
		return {"ok": false, "error": issue}
	# Keep this object's signal connections and commit only a complete candidate.
	var candidate := ValleyQuest.new()
	var position := candidate.restore(data)
	letters = candidate.letters
	delivered = candidate.delivered
	lamps = candidate.lamps
	mirror_turn = candidate.mirror_turn
	solved = candidate.solved
	finished = candidate.finished
	elapsed = candidate.elapsed
	return {"ok": true, "position": position}

func restore(data: Dictionary) -> Vector2:
	# Save data is untrusted: whitelist IDs, deduplicate and recompute invariants.
	letters.clear()
	delivered.clear()
	lamps.clear()
	for id in data.get("delivered", []) if data.get("delivered", []) is Array else []:
		if id is String and LETTERS.has(id) and not delivered.has(id):
			delivered.append(id)
	for id in data.get("letters", []) if data.get("letters", []) is Array else []:
		if id is String and LETTERS.has(id) and not letters.has(id) and not delivered.has(id):
			letters.append(id)
	for id in data.get("lamps", []) if data.get("lamps", []) is Array else []:
		if (id is int or id is float) and int(id) >= 0 and int(id) <= 2 and not lamps.has(int(id)):
			lamps.append(int(id))
	mirror_turn = clampi(int(data.get("mirror_turn", 0)) if data.get("mirror_turn", 0) is float or data.get("mirror_turn", 0) is int else 0, 0, 3)
	solved = data.get("solved", false) == true or delivered.has("star") or letters.has("star")
	check_beam()
	finished = delivered.size() == 3 and data.get("finished", false) == true
	var raw_elapsed: Variant = data.get("elapsed", 0.0)
	elapsed = clampf(float(raw_elapsed), 0.0, 36000.0) if raw_elapsed is float or raw_elapsed is int else 0.0
	if not is_finite(elapsed):
		elapsed = 0.0
	var p: Variant = data.get("position", [])
	if p is Array and p.size() == 2 and (p[0] is float or p[0] is int) and (p[1] is float or p[1] is int):
		var pos := Vector2(float(p[0]), float(p[1]))
		if is_finite(pos.x) and is_finite(pos.y) and pos.x > -14.0 and pos.x < 14.0 and pos.y > -12.0 and pos.y < 12.0:
			return pos
	return Vector2(-8.0, 7.0)
