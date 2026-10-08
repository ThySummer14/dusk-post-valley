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
