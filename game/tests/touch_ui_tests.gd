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
func finger(id: int, at: Vector2, down: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)
func drag(id: int, at: Vector2, relative := Vector2.ZERO) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = at
	event.relative = relative
	root.push_input(event, true)
func tap(button: Control, id := 1) -> void:
	var at := button.get_global_rect().get_center()
	finger(id, at, true)
	finger(id, at, false)
func mouse_click(button: Control) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
func run() -> void:
	root.size = Vector2i(812,375)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.running = false
	game._show_title()
	await settle()
	check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "No global single-finger mouse emulation")
	tap(game.modal_footer.get_child(0))
	check(game.running and not game.modal_open, "Native touch starts actual main scene")
	await settle()
	tap(game.header_buttons.get_child(1))
	check(game.modal_open and "歇一会" in game.modal_title.text, "Native touch opens pause menu")
	await settle()
	tap(game.modal_footer.get_child(0))
	check(not game.modal_open, "Native touch resumes pause menu")
	await settle()
	var origin := Vector2(70,220)
	finger(0, origin, true)
	drag(0, origin + Vector2(45,0), Vector2(45,0))
	check(game.touch.pointer == 0 and game.touch.axis.x > 0.5, "First finger controls walking joystick")
	game.current_interaction = {"kind":"lamp", "id":0}
	game.action_button.visible = true
	game.action_button.disabled = false
	tap(game.action_button, 1)
	check(game.quest.lamps.has(0), "Independent second finger activates interaction")
	check(game.touch.pointer == 0 and game.touch.axis.x > 0.5, "Second-finger release preserves walking finger")
	tap(game.header_buttons.get_child(1), 2)
	check(game.modal_open and game.touch.pointer == -1, "Opening pause with third finger cancels movement")
	finger(0, origin + Vector2(45,0), false)
	await settle()
	var resume: Button = game.modal_footer.get_child(0)
	var at := resume.get_global_rect().get_center()
	finger(3,at,true)
	finger(3,at,false,true)
	check(game.modal_open and resume.touch_id == -1, "Canceled button touch does not activate or remain held")
	finger(3,at,true)
	drag(3,at+Vector2(40,0),Vector2(40,0))
	finger(3,at+Vector2(40,0),false)
	check(game.modal_open, "Dragging inside a wide button does not activate it")
	finger(3,at,true)
	drag(3,at+Vector2(400,0),Vector2(400,0))
	drag(3,at,Vector2(-400,0))
	finger(3,at,false)
	check(game.modal_open and resume.touch_id == -1, "Dragging out and back does not activate or stick")
	finger(3,at,true)
	finger(3,Vector2.ZERO,false)
	check(game.modal_open and resume.touch_id == -1, "Release outside without drag event cancels")
	resume.disabled = true
	tap(resume,3)
	check(game.modal_open and resume.touch_id == -1, "Disabled button ignores native touch")
	resume.disabled = false
	finger(3,at,true)
	finger(4,at,true)
	finger(4,at,false)
	check(game.modal_open and resume.touch_id == 3, "Another finger cannot release a held button")
	finger(3,at,false)
	check(not game.modal_open, "Original finger activates exactly once after other finger releases")
	await settle()
	tap(game.header_buttons.get_child(1))
	await settle()
	at = game.modal_footer.get_child(0).get_global_rect().get_center()
	finger(5,at,true)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await settle()
	finger(5,at,false)
	check(game.modal_open and game.touch.pointer == -1, "Focus loss clears held touch and stale release cannot resume")
	tap(game.modal_footer.get_child(0),5)
	check(not game.modal_open, "Fresh touch resumes after focus loss")
	await settle()
	for i in range(3):
		tap(game.header_buttons.get_child(1),6)
		await settle()
		tap(game.modal_footer.get_child(0),6)
		await settle()
	check(not game.modal_open, "Repeated touch index reuse leaves no stuck state")
	mouse_click(game.header_buttons.get_child(1))
	await settle()
	check(game.modal_open, "Desktop mouse still opens pause")
	mouse_click(game.modal_footer.get_child(0))
	check(not game.modal_open, "Desktop mouse still resumes pause")
	game._show_help()
	await settle()
	var scroll: Control = game.modal_scroll
	var middle := scroll.get_global_rect().get_center()
	finger(7,middle,true)
	drag(7,middle-Vector2(0,50),Vector2(0,-50))
	finger(7,middle-Vector2(0,50),false)
	check(game.modal_scroll.scroll_vertical == 50, "Native touch scrolls long actual help body")
	check(game.modal_open, "Scrolling help does not activate footer")
	var before: int = game.modal_scroll.scroll_vertical
	finger(7,middle,true)
	drag(7,middle-Vector2(0,5),Vector2(0,-5))
	finger(7,middle-Vector2(0,5),false)
	check(game.modal_scroll.scroll_vertical == before, "Small touch jitter does not scroll")
	finger(7,middle,true)
	var footer_center: Vector2 = game.modal_footer.get_child(0).get_global_rect().get_center()
	drag(7,footer_center,footer_center-middle)
	finger(7,footer_center,false)
	check(game.modal_open, "Body swipe ending over footer does not close help")
	finger(7,middle,true)
	finger(7,middle,false,true)
	before = game.modal_scroll.scroll_vertical
	drag(7,middle-Vector2(0,70),Vector2(0,-70))
	check(game.modal_scroll.scroll_vertical == before and game.modal_scroll.touch_id == -1, "Canceled scroll ignores later stale drag")
	finger(7,middle,true)
	drag(8,middle-Vector2(0,80),Vector2(0,-80))
	check(game.modal_scroll.scroll_vertical == before, "Unrelated finger cannot move captured scroll")
	finger(7,middle,false)
	tap(game.modal_footer.get_child(0),7)
	check(not game.modal_open, "Help footer remains touch-usable after scrolling")
	game.queue_free()
	await process_frame
	print("TOUCH_UI_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed == 0 else 1)
