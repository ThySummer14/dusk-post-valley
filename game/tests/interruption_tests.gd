extends SceneTree
var passed := 0
var failed := 0
var game: Node
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	passed += int(ok)
	failed += int(not ok)
	print("PASS " if ok else "FAIL ", label)
func settle() -> void:
	for i in range(6): await process_frame
func finger(id: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	root.push_input(event, true)
func drag(id: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = at
	root.push_input(event, true)
func key(code: Key, down: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.echo = echo
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(button: Control, id: int) -> void:
	var at := button.get_global_rect().get_center()
	finger(id, at, true)
	finger(id, at, false)
func run() -> void:
	root.size = Vector2i(812,375)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await settle()
	key(KEY_D, true)
	check(Input.is_action_pressed("walk_right"), "Native key event starts movement before pause")
	game._process(0.05)
	game._show_pause()
	check(not Input.is_action_pressed("walk_right"), "Opening pause clears held keyboard movement")
	var paused_position: Vector2 = game.player_pos
	game._process(0.05)
	check(game.player_pos == paused_position, "Paused movement remains stopped")
	game._close_modal()
	game._process(0.05)
	check(game.player_pos == paused_position, "Resume does not replay stale keyboard movement")
	key(KEY_D, true, true)
	game._process(0.05)
	check(game.player_pos == paused_position, "Held-key auto-repeat does not restart movement after resume")
	key(KEY_D, false)
	game._show_help()
	await settle()
	var middle: Vector2 = game.modal_scroll.get_global_rect().get_center()
	finger(7,middle,true)
	drag(7,middle-Vector2(0,40))
	check(game.modal_scroll.touch_id == 7, "Help scroll captures real touch before rotation")
	root.size = Vector2i(375,812)
	await settle()
	check(game.modal_scroll.touch_id == -1, "Orientation change cancels held scroll capture")
	var before: int = game.modal_scroll.scroll_vertical
	drag(7,middle-Vector2(0,120))
	check(game.modal_scroll.scroll_vertical == before, "Old-orientation scroll drag is ignored")
	finger(7,middle,false)
	var button: Button = game.modal_footer.get_child(0)
	finger(8,button.get_global_rect().get_center(),true)
	check(button.touch_id == 8, "Help close button captures real touch before resize")
	root.size = Vector2i(812,375)
	await settle()
	check(button.touch_id == -1 and not button.button_pressed, "Orientation change clears held button visual and capture")
	finger(8,button.get_global_rect().get_center(),false)
	check(game.modal_open, "Stale release after rotation does not close help")
	tap(button, 9)
	check(not game.modal_open, "Fresh touch closes help after orientation interruption")
	for open_method in ["_show_help", "_show_journal", "_confirm_restart"]:
		key(KEY_D, true)
		game.call(open_method)
		check(not Input.is_action_pressed("walk_right"), open_method + " clears held movement")
		key(KEY_D, false)
		key(KEY_D, true)
		game._close_modal()
		check(not Input.is_action_pressed("walk_right"), open_method + " ignores movement begun while modal was open")
		key(KEY_D, false)
	game._show_help()
	await settle()
	middle = game.modal_scroll.get_global_rect().get_center()
	finger(10,middle,true)
	drag(10,middle-Vector2(0,40))
	root.size = Vector2i(800,375)
	await settle()
	before = game.modal_scroll.scroll_vertical
	drag(10,middle-Vector2(0,100))
	check(game.modal_scroll.touch_id == -1 and game.modal_scroll.scroll_vertical == before, "Browser-size change ignores stale drag while body remains scrollable")
	finger(10,middle,false)
	middle = game.modal_scroll.get_global_rect().get_center()
	finger(11,middle,true)
	drag(11,middle-Vector2(0,40))
	check(game.modal_scroll.scroll_vertical > before, "Fresh touch scroll works after resize")
	finger(11,middle,false)
	game._close_modal()
	key(KEY_D, true)
	var start: Vector2 = game.player_pos
	game._process(0.05)
	check(game.player_pos != start, "Fresh keyboard input still moves after interruptions")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.modal_open and not Input.is_action_pressed("walk_right"), "Focus loss stops keyboard and opens pause")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._close_modal()
	start = game.player_pos
	game._process(0.05)
	check(game.player_pos == start, "Focus return and resume do not replay stale movement")
	key(KEY_D, false)
	game.queue_free()
	await process_frame
	print("INTERRUPTION_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed == 0 else 1)
