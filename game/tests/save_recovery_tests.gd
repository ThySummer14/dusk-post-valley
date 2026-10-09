extends SceneTree
const Quest = preload("res://scripts/quest_state.gd")
const Rules = preload("res://scripts/world_rules.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	if OS.get_environment("DUSK_DISPOSABLE_TEST_DATA") != "1" or OS.get_cmdline_user_args().has("--test-world"):
		push_error("Use disposable XDG directories and DUSK_DISPOSABLE_TEST_DATA=1; omit --test-world to test real startup persistence.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	passed += int(ok)
	failed += int(not ok)
	print("PASS " if ok else "FAIL ", label)

func changed(base: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := base.duplicate(true)
	result[key] = value
	return result

func write_fixture(path: String, bytes: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(bytes)
	file.close()

func all_reachable_states_roundtrip() -> bool:
	var initial := Quest.new().to_data(Rules.START)
	var pending: Array[Dictionary] = [initial]
	var visited := {JSON.stringify(initial): true}
	var cursor := 0
	var transitions := 0
	while cursor < pending.size():
		var state: Dictionary = pending[cursor]
		cursor += 1
		var restored := Quest.new()
		var result := restored.restore_checked(JSON.parse_string(JSON.stringify(state)))
		if not result.ok or restored.to_data(result.position) != state:
			print("REACHABLE_REJECTED ", JSON.stringify(state), " ", result)
			return false
		# Explore every public quest operation, including no-ops/repetition, all
		# three lights after solving, turning away from the beam, and restarting.
		for action in range(12):
			var next := Quest.new()
			next.restore(state)
			if action < 3:
				next.collect(Quest.LETTERS[action])
			elif action < 6:
				next.deliver(Quest.LETTERS[action - 3])
			elif action < 9:
				next.light_lamp(action - 6)
			elif action == 9:
				next.turn_mirror()
			elif action == 10:
				next.return_to_post()
			else:
				next = Quest.new()
			transitions += 1
			var data := next.to_data(Rules.START)
			var key := JSON.stringify(data)
			if not visited.has(key):
				visited[key] = true
				pending.append(data)
	print("REACHABLE_STATES ", pending.size(), " TRANSITIONS ", transitions)
	return true

func run() -> void:
	check(all_reachable_states_roundtrip(), "Every reachable public quest state roundtrips through strict v1 validation")
	var seed := Quest.new()
	seed.collect("cedar")
	seed.deliver("cedar")
	seed.light_lamp(2)
	seed.turn_mirror()
	seed.turn_mirror()
	seed.turn_mirror() # A solved puzzle remains solved after turning away.
	seed.collect("star")
	seed.elapsed = 1234.5
	var valid := seed.to_data(Rules.START)
	var malformed: Array = [null, [], {}, changed(valid, "version", 99), changed(valid, "version", 1.5), changed(valid, "version", "1"), changed(valid, "future_chapter", 5)]
	for key in valid:
		var missing := valid.duplicate(true)
		missing.erase(key)
		malformed.append(missing)
	for entry in [["letters", "star"], ["letters", ["bogus"]], ["letters", ["star", "star"]], ["letters", ["cedar"]], ["delivered", "cedar"], ["delivered", [42]], ["lamps", "2"], ["lamps", [2, 2]], ["lamps", [1.5]], ["lamps", [3]], ["mirror_turn", "2"], ["mirror_turn", 1.5], ["mirror_turn", 4], ["solved", 1], ["solved", false], ["finished", "false"], ["finished", true], ["elapsed", "12"], ["elapsed", -1], ["position", [1]], ["position", [1, "2"]], ["position", [1, 2, 3]]]:
		malformed.append(changed(valid, entry[0], entry[1]))
	var live := Quest.new()
	live.collect("river")
	var before := live.to_data(Vector2.ZERO)
	for i in malformed.size():
		var result := live.restore_checked(malformed[i])
		check(not result.ok and not result.error.is_empty() and live.to_data(Vector2.ZERO) == before, "Invalid candidate %d never partly mutates live state" % i)
	for key in ["elapsed", "mirror_turn", "version"]:
		check(not live.restore_checked(changed(valid, key, INF)).ok, "Nonfinite " + key + " rejected")
	check(not live.restore_checked(changed(valid, "position", [NAN, 0])).ok, "Nonfinite position rejected")
	var serialized: Variant = JSON.parse_string(JSON.stringify(valid))
	check(live.restore_checked(serialized).ok and live.to_data(Rules.START) == valid, "JSON numeric types restore all valid v1 progress")
	check(live.solved and live.mirror_turn == 3, "Sticky solved state survives rotating away from beam")
	var moved := changed(valid, "position", [200, 0])
	check(live.restore_checked(moved).position == Rules.START, "Existing out-of-map safe-start recovery remains unchanged")
	check(live.restore_checked(changed(valid, "elapsed", 36001)).ok and live.elapsed == 36000, "Existing long-session elapsed normalization remains unchanged")

	# These are actual main scenes with _ready's normal load -> changed -> save
	# chain, not extracted methods or --test-world's persistence bypass.
	var startup_cases := ["{damaged save bytes", "{}", "[]", JSON.stringify(changed(valid, "version", 99)), JSON.stringify(changed(valid, "delivered", "cedar")), JSON.stringify(changed(valid, "future_chapter", 5))]
	var missing := valid.duplicate(true)
	missing.erase("lamps")
	startup_cases.append(JSON.stringify(missing))
	for i in startup_cases.size():
		var path := "user://save-recovery-startup-%d.json" % i
		var original: String = startup_cases[i]
		write_fixture(path, original)
		var game: Node = load("res://main.tscn").instantiate()
		game.save_path = path
		game.set_process(false)
		root.add_child(game)
		await process_frame
		check(not game.testing and game.save_read_only and not game.has_save, "Startup %d enters real read-only protection" % i)
		check(FileAccess.get_file_as_string(path) == original and not FileAccess.file_exists(path + ".tmp"), "Startup %d auto-save preserves exact original bytes" % i)
		game._start_game()
		check("已保留原文件" in game.toast_label.text and "暂不保存" in game.toast_label.text, "Startup %d tells player that this run will not save" % i)
		game.quest.collect("river") # Emits changed, which attempts another save.
		game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		check(FileAccess.get_file_as_string(path) == original, "Startup %d state changes and close cannot overwrite protected save" % i)
		game._confirm_restart()
		game._show_pause() # Cancel restart without invoking its affirmative action.
		check(game.save_read_only and FileAccess.get_file_as_string(path) == original, "Startup %d restart prompt/cancel retains protection" % i)
		game._restart() # Explicit fixture-only confirmation may replace it.
		var restarted: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(not game.save_read_only and game.save_warning.is_empty() and Quest.save_issue(restarted).is_empty() and restarted.delivered.is_empty(), "Startup %d explicit restart writes valid new progress" % i)
		game.sound_player.stop()
		game.ambience.stop()
		game.queue_free()
		await process_frame
		DirAccess.remove_absolute(path)

	seed.collect("river")
	seed.deliver("river")
	seed.deliver("star")
	seed.return_to_post()
	var completed := seed.to_data(Rules.START)
	var valid_path := "user://save-recovery-valid-v1.json"
	write_fixture(valid_path, JSON.stringify(completed))
	var game: Node = load("res://main.tscn").instantiate()
	game.save_path = valid_path
	game.set_process(false)
	root.add_child(game)
	await process_frame
	check(not game.testing and game.has_save and not game.save_read_only and game.save_warning.is_empty(), "Valid v1 startup continues normally without warning")
	check(game.quest.to_data(game.player_pos) == completed, "Valid v1 restores every field including completed route")
	check(FileAccess.get_file_as_string(valid_path) == JSON.stringify(completed), "Valid v1 startup automatic save retains complete progress")
	game.sound_player.stop()
	game.ambience.stop()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(valid_path)
	await create_timer(0.1).timeout # Let the real startup audio mixer release its last buffer.
	print("SAVE_RECOVERY_RESULT ", passed, " passed / ", failed, " failed")
	quit(0 if failed == 0 else 1)
