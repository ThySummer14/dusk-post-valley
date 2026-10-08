extends SceneTree
const Quest = preload("res://scripts/quest_state.gd")
const Touch = preload("res://scripts/touch_input.gd")
const Rules = preload("res://scripts/world_rules.gd")
var passed := 0
var failed := 0
var results: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		results.append("PASS " + label)
	else:
		failed += 1
		results.append("FAIL " + label)
		push_error(label)

func run() -> void:
	var q := Quest.new()
	check(not q.return_to_post(), "Cannot finish before deliveries")
	check(not q.collect("unknown"), "Unknown letter rejected")
	check(not q.collect("star"), "Hidden letter gated by light puzzle")
	check(not q.deliver("cedar"), "Cannot deliver a missing letter")
	check(q.collect("cedar"), "First pickup accepted")
	check(not q.collect("cedar"), "Repeated pickup idempotent")
	check(q.deliver("cedar"), "Correct delivery accepted")
	check(not q.deliver("cedar"), "Repeated delivery idempotent")
	check(not q.collect("cedar"), "Delivered letter cannot reappear")
	check(not q.light_lamp(9), "Unknown lamp rejected")
	check(q.light_lamp(0), "Lamp lights once")
	check(not q.light_lamp(0), "Repeat lighting idempotent")
	q.turn_mirror()
	q.turn_mirror()
	check(not q.solved, "Mirror cannot solve without source lamp")
	q.light_lamp(2)
	check(q.solved, "Source lamp plus correct mirror orientation solves")
	check(q.collect("star"), "Revealed letter now collectible")
	q.turn_mirror()
	check(q.solved, "Solved puzzle remains solved after extra rotation")
	q.collect("river")
	q.deliver("river")
	q.deliver("star")
	check(q.return_to_post(), "Three deliveries and return to post completes loop")
	check(not q.return_to_post(), "Ending cannot trigger twice")
	var restored := Quest.new()
	var p := restored.restore(q.to_data(Vector2(1, 2)))
	check(p == Vector2(1, 2) and restored.finished and restored.delivered.size() == 3, "Save roundtrip retains complete state and position")
	var corrupt := Quest.new()
	p = corrupt.restore({"letters": ["cedar", "cedar", "bogus"], "delivered": ["cedar", "cedar"], "lamps": [2, 2, 5, "a"], "position": [200, 0], "mirror_turn": "bad", "elapsed": "bad", "finished": true})
	check(corrupt.letters.is_empty() and corrupt.delivered == ["cedar"], "Corrupt save deduplicates and excludes already-delivered inventory")
	check(corrupt.lamps == [2] and not corrupt.finished and p == Rules.START, "Corrupt progress and invalid position safely recover")
	var touch := Touch.new()
	check(touch.press(2, Vector2(100, 100), true), "First touch owns joystick")
	check(not touch.press(3, Vector2(200, 100), true), "Second finger cannot steal movement")
	touch.drag(3, Vector2(300, 100))
	check(touch.axis == Vector2.ZERO, "Unowned drag ignored")
	touch.drag(2, Vector2(300, 100))
	check(touch.axis == Vector2.RIGHT, "Joystick clamps travel")
	touch.release(3)
	check(touch.pointer == 2, "Other finger release preserves owner")
	touch.release(2)
	check(touch.pointer == -1 and touch.axis == Vector2.ZERO, "Touch release clears movement")
	touch.press(1, Vector2.ZERO, true)
	touch.drag(1, Vector2(50, 0))
	touch.cancel()
	check(touch.pointer == -1 and touch.axis == Vector2.ZERO, "Cancel clears pointer and axis")
	check(not touch.press(1, Vector2.ZERO, false), "Modal gate rejects touch movement")
	var rules := Rules.new()
	check(not rules.can_walk(Vector2(4, -3)), "River blocks unsafe crossing")
	check(rules.can_walk(Vector2(4, 2)), "Bridge permits crossing")
	check(not rules.can_walk(Vector2(14, 0)), "Outer bounds prevent leaving map")
	rules.obstacles.append(Rect2(-1, -1, 2, 2))
	var moved := rules.move(Vector2(-3, 0), Vector2(6, 0))
	check(moved.x < -1.28, "Large frame substeps cannot tunnel through house")
	moved = rules.move(Vector2(-1.4, 0), Vector2(0.5, 1))
	check(moved.x < -1.28 and moved.y > 0.9, "Player slides along obstacle edge")
	check(is_equal_approx(Rules.height_at(Vector2(0, -8)), 1.32), "Terrain elevation matches rear slope")
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.testing and game.running, "Full scene boots in isolated test mode")
	check(game.world.interactables.size() == 14, "All authored interactables spawn")
	check(game.world.letters.size() == 3 and game.world.lamp_nodes.size() == 3, "World has three letters and lamps")
	check(game.world.rules.can_walk(Rules.START), "Start point is walkable")
	var checked_surfaces := 0
	var normal_errors := 0
	for mesh_node in game.world.find_children("*", "MeshInstance3D", true, false):
		if mesh_node.get_meta("upward_surface", false):
			checked_surfaces += 1
			var normals: PackedVector3Array = mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			for normal in normals:
				if normal.y < 0.2:
					normal_errors += 1
	print("NORMAL_AUDIT surfaces=", checked_surfaces, " invalid=", normal_errors)
	check(checked_surfaces >= 15 and normal_errors == 0, "All ground/path/roof surfaces have upward Godot clockwise normals")
	# Flood fill in navigation space checks all real interaction approaches.
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 111, 94)
	grid.cell_size = Vector2(0.25, 0.25)
	grid.offset = Vector2(-13.5, -11.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(111):
		for y in range(94):
			grid.set_point_solid(Vector2i(x, y), not game.world.rules.can_walk(grid.get_point_position(Vector2i(x, y))))
	var start_cell := Vector2i((Rules.START - grid.offset) / grid.cell_size)
	for item in game.world.interactables:
		var goal := Vector2i((item.pos - grid.offset) / grid.cell_size)
		var path := grid.get_id_path(start_cell, goal)
		check(not path.is_empty(), "Reachable interaction: " + str(item.kind) + " / " + str(item.id))
	game.touch.press(8, Vector2.ZERO, true)
	game.touch.drag(8, Vector2(40, 0))
	game._show_journal()
	check(game.modal_open and game.touch.axis == Vector2.ZERO and game.touch.pointer == -1, "Opening journal cancels held touch")
	game._close_modal()
	check(not game.modal_open and game.touch.pointer == -1, "Closing modal does not restore movement")
	game.touch.press(9, Vector2.ZERO, true)
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.modal_open and game.touch.pointer == -1, "Focus loss pauses and cleans touch")
	game._close_modal()
	game.current_interaction = {"kind": "letter", "id": "cedar", "pos": Vector2(-5.5, 6.7)}
	game._interact()
	check(game.quest.letters.has("cedar") and game.modal_open and not game.world.letters.cedar.visible, "Scene pickup changes state, opens letter, hides world pickup")
	game._close_modal()
	game.current_interaction = {"kind": "house", "id": "cedar", "pos": Vector2(-8, -4.7)}
	game._interact()
	check(game.quest.delivered.has("cedar") and game.modal_open, "Scene delivery opens correct reply")
	game._close_modal()
	game._confirm_restart()
	check(game.quest.delivered.has("cedar"), "Reset confirmation itself does not erase progress")
	game._show_pause()
	check(game.quest.delivered.has("cedar"), "Cancelling reset retains progress")
	game._restart()
	check(game.quest.delivered.is_empty() and not game.quest.finished and game.player_pos == Rules.START, "Confirmed restart resets complete state")
	check(game.subviewport.size.y == 270, "World renders low resolution independent of full-resolution UI")
	var isolated_save := "user://valley_atomic_test_" + str(Time.get_ticks_usec()) + ".json"
	game.save_path = isolated_save
	game.testing = false
	game._save_game()
	check(FileAccess.file_exists(isolated_save) and not FileAccess.file_exists(isolated_save + ".tmp"), "Atomic save commits and leaves no partial file")
	var initial_save: Variant = JSON.parse_string(FileAccess.get_file_as_string(isolated_save))
	check(initial_save is Dictionary and initial_save.version == 1, "Atomic save contains valid versioned JSON")
	var broken := FileAccess.open(isolated_save, FileAccess.WRITE)
	broken.store_string("{damaged save bytes")
	broken.close()
	game._load_game()
	check(game.save_read_only, "Malformed JSON file enables read-only preservation")
	game._save_game()
	check(FileAccess.get_file_as_string(isolated_save) == "{damaged save bytes", "Failed load is not overwritten by next automatic save")
	game.testing = true
	DirAccess.remove_absolute(isolated_save)
	game.queue_free()
	await process_frame
	for line in results:
		print(line)
	print("RESULT ", passed, " passed / ", failed, " failed")
	quit(0 if failed == 0 else 1)
