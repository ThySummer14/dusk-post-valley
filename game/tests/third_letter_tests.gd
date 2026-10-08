extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	passed += int(ok)
	failed += int(not ok)
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var blocked_samples := 0
	for i in range(game.world.EAST_ROUTE.size()-1):
		for step in range(31):
			var point: Vector2 = game.world.EAST_ROUTE[i].lerp(game.world.EAST_ROUTE[i+1],float(step)/30.0)
			blocked_samples += int(not game.world.rules.can_walk(point))
	check(blocked_samples == 0,"Authored east-bank path reaches the observatory without drawing through a house")
	check(not game.world.beam.visible,"Unlit mirror has no unsupported light beam")
	game.quest.turn_mirror()
	game.quest.turn_mirror()
	check(not game.quest.solved,"Facing reeds without a source light does not solve")
	game.current_interaction={"kind":"lamp","id":2,"pos":Vector2(-0.5,-5)}
	game._interact()
	check(game.quest.solved and game.world.letters.star.visible,"Lighting an already aligned mirror reveals the letter")
	check(game.modal_open and "找到一封信" in game.modal_title.text,"Reverse-order solution receives the same discovery confirmation")
	check(not game.prompt_label.visible,"Discovery modal suppresses stale world prompts")
	game._close_modal()
	var target: Vector3 = game.world.beam_target
	check(target.distance_to(game.world.ground(Vector2(0.4,-8.5),0.09))<0.01,"North-facing beam visibly ends at the hidden-letter location")
	game.quest.turn_mirror()
	check(game.world.beam_target.x > game.world.mirror.position.x,"East-facing preview lands east")
	check(game.world.beam.visible and game.world.beam_target != target,"Turning after discovery moves the visible light instead of leaving a false fixed ray")
	check(game.world.letters.star.visible and game.quest.solved,"Discovered letter remains accessible after mirror is turned away")
	game.quest.turn_mirror()
	check(game.world.beam_target.z > game.world.mirror.position.z,"South-facing preview lands south")
	game.quest.turn_mirror()
	check(game.world.beam_target.x < game.world.mirror.position.x,"West-facing preview lands west")
	for id in ["cedar","river"]:
		game.quest.collect(id)
		game.quest.deliver(id)
	game.quest.lamps.clear()
	game.quest.solved=false
	game.player_pos=Vector2(8,2)
	game._update_objective()
	check("回过木桥" in game.objective_label.text,"East bank objective explains the return crossing")
	game.player_pos=Vector2(1,2)
	game._update_objective()
	check("沿西岸石径" in game.objective_label.text,"West bank objective follows the physical path")
	game.quest.solved=true
	game.quest.collect("star")
	game._update_objective()
	check("过桥去东岸" in game.objective_label.text,"Carrying the last letter explains the east-bank crossing")
	game.player_pos=Vector2(8,2)
	game._update_objective()
	check("紫瓦观星屋" in game.objective_label.text,"East bank carrying objective names the correct roof landmark")
	game.queue_free()
	await process_frame
	print("THIRD_LETTER_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed == 0 else 1)
