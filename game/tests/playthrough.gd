extends SceneTree
const STEP := 1.0 / 60.0
var checks := 0
var failure := false
var simulated_frames := 0
var total_distance := 0.0
var game: Node
var grid: AStarGrid2D

func _initialize() -> void:
	call_deferred("run")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failure = true
		push_error(message)
	print("PASS " if value else "FAIL ", message)

func cell(p: Vector2) -> Vector2i:
	return Vector2i(((p - grid.offset) / grid.cell_size).round())

func walk_to(kind: String, id: Variant) -> void:
	var target := Vector2.ZERO
	for item in game.world.interactables:
		if item.kind == kind and item.id == id:
			target = item.pos
			break
	var path := grid.get_point_path(cell(game.player_pos), cell(target))
	verify(not path.is_empty(), "Route exists to " + kind + "/" + str(id))
	for point in path:
		var safety := 0
		while game.player_pos.distance_to(point) > 0.08 and safety < 70:
			safety += 1
			var before: Vector2 = game.player_pos
			var direction: Vector2 = (point - before).normalized()
			var x := direction.dot(Vector2(0.832, -0.555))
			var y := direction.dot(Vector2(0.555, 0.832))
			Input.action_press("walk_right", maxf(x, 0))
			Input.action_press("walk_left", maxf(-x, 0))
			Input.action_press("walk_down", maxf(y, 0))
			Input.action_press("walk_up", maxf(-y, 0))
			game._process(STEP)
			simulated_frames += 1
			total_distance += game.player_pos.distance_to(before)
		if safety >= 70:
			verify(false, "Movement stuck approaching " + str(point))
			break
	for action in ["walk_right", "walk_left", "walk_down", "walk_up"]:
		Input.action_release(action)
	game._process(STEP)
	verify(game.player_pos.distance_to(target) < 0.4, "Actual controller reached " + kind + "/" + str(id))
	verify(not game.current_interaction.is_empty() and game.current_interaction.kind == kind and game.current_interaction.id == id, "Proximity selected correct object")

func interact() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	game._input(event)

func close_dialog() -> void:
	if game.modal_open:
		interact()

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 111, 94)
	grid.cell_size = Vector2(0.25, 0.25)
	grid.offset = Vector2(-13.5, -11.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(111):
		for y in range(94):
			var c := Vector2i(x, y)
			grid.set_point_solid(c, not game.world.rules.can_walk(grid.get_point_position(c)))
	walk_to("letter", "cedar")
	interact()
	verify(game.quest.letters.has("cedar"), "Actual E key picked up first letter")
	close_dialog()
	walk_to("lamp", 0)
	interact()
	verify(game.quest.lamps.has(0), "First route lamp lights")
	walk_to("house", "cedar")
	interact()
	verify(game.quest.delivered.has("cedar"), "First resident receives letter")
	close_dialog()
	walk_to("lamp", 1)
	interact()
	verify(game.quest.lamps.has(1), "Crossed real bridge to second lamp")
	walk_to("letter", "river")
	interact()
	close_dialog()
	walk_to("house", "river")
	interact()
	verify(game.quest.delivered.has("river"), "Second resident receives letter")
	close_dialog()
	walk_to("lamp", 2)
	interact()
	walk_to("mirror", "mirror")
	interact()
	verify(not game.quest.solved, "First mirror turn gives directional feedback")
	interact()
	verify(game.quest.solved and game.world.letters.star.visible, "Second turn reveals real hidden letter node")
	close_dialog()
	walk_to("letter", "star")
	interact()
	close_dialog()
	walk_to("house", "star")
	interact()
	verify(game.quest.delivered.size() == 3, "Third resident receives final letter")
	close_dialog()
	walk_to("post", "post")
	interact()
	verify(game.quest.finished and game.modal_open, "Walking back and pressing E opens ending")
	close_dialog()
	verify(game.running and not game.modal_open, "Ending permits continued free exploration")
	print("PLAYTHROUGH ", checks, " checks; frames=", simulated_frames, "; simulated_walk_seconds=", snappedf(simulated_frames * STEP, 0.1), "; distance_m=", snappedf(total_distance, 0.1), "; failures=", failure)
	game.queue_free()
	await process_frame
	quit(1 if failure else 0)
