extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	passed += int(ok)
	failed += int(not ok)
	print("PASS " if ok else "FAIL ",title)
func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.testing = true
	game.set_process(false)
	for dimensions in [Vector2i(1180,812), Vector2i(375,812), Vector2i(812,375)]:
		root.size = dimensions
		for i in range(6):await process_frame
		game._show_title()
		for i in range(6):await process_frame
		check(root.get_visible_rect().size == Vector2(dimensions),"Deferred resize settles at actual viewport " + str(dimensions))
		check(game.modal_body.get_combined_minimum_size().y <= game.modal_scroll.size.y + 1,"Intro fully visible without half-line clipping " + str(dimensions))
		check(not game.modal_scroll_hint.visible,"Short intro needs no scrolling " + str(dimensions))
		game._close_modal()
	root.size = Vector2i(280,600)
	for i in range(6):await process_frame
	game.running = true
	game._show_pause()
	for i in range(6):await process_frame
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1.5).encloses(game.panel.get_global_rect()), "Minimum-width pause settings row remains inside viewport")
	game._close_modal()
	game.current_interaction={"kind":"letter","id":"cedar","pos":Vector2(-5.5,6.7)}
	game._interact()
	check("红瓦屋" in game.objective_label.text and "杉婆婆" in game.objective_label.text,"Carried letter objective identifies roof landmark and recipient")
	game._close_modal()
	game.player_pos = Vector2(-8,-4.7)
	game._update_nearby()
	check("杉婆婆" in game.prompt_label.text,"Door prompt names its recipient")
	game._interact()
	check("已送达" in game.modal_title.text,"Delivery dialog gives explicit confirmation")
	check(not game.prompt_label.visible and not game.action_button.visible, "Delivery modal suppresses stale world-interaction prompt")
	game._close_modal()
	check("信已送到杉婆婆手里" in game.toast_label.text and game.label_timer>0,"Closing delivery leaves a brief clear receipt")
	check(game.prompt_label.visible, "Closing modal restores world interaction only after recomputation")
	check("已收信" in game.prompt_label.text,"Delivered door prompt stops asking for another delivery")
	game.queue_free()
	await process_frame
	print("USABILITY_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)
