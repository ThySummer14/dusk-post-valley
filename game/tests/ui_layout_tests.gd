extends SceneTree
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(label)
	print("PASS " if value else "FAIL ", label)

func inside(rect: Rect2, bounds: Rect2) -> bool:
	return bounds.grow(1.5).encloses(rect)

func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for dimensions in [Vector2i(375,812), Vector2i(812,375)]:
		root.size = dimensions
		await process_frame
		game._resize_world()
		await process_frame
		await process_frame
		var size: Vector2 = root.get_visible_rect().size
		var bounds := Rect2(Vector2.ZERO, size)
		print("ACTUAL_VIEWPORT ", dimensions, " => ", size, " CONTENT_SCALE ", root.content_scale_size)
		check(size == Vector2(dimensions), "Actual logical viewport matches " + str(dimensions))
		game.action_button.visible = true
		await process_frame
		check(inside(game.action_button.get_global_rect(), bounds), "Interaction touch target remains inside viewport")
		check(game.action_button.size.x >= 76 and game.action_button.size.y >= 76, "Interaction target is large enough for touch")
		check(not game.action_button.get_global_rect().intersects(Rect2(0,0,size.x*0.48,size.y)), "Interaction target does not overlap left movement zone")
		check(inside(game.header_buttons.get_global_rect(), bounds), "Bag and menu targets remain inside viewport")
		check(not game.header_buttons.get_global_rect().intersects(game.action_button.get_global_rect()), "Menu and interaction targets do not overlap")
		game._show_help()
		await process_frame
		await process_frame
		print("MODAL_RECT ", game.panel.get_global_rect(), " CLOSE_RECT ", game.modal_footer.get_child(0).get_global_rect())
		check(inside(game.panel.get_global_rect(), bounds), "Long help panel fits physical viewport proxy")
		check(inside(game.modal_footer.get_child(0).get_global_rect(), bounds), "Close button remains reachable without scrolling")
		check(game.modal_scroll.size.y > 40, "Letter body has a real scroll viewport")
		if dimensions.y < 500:
			check(game.modal_scroll.get_v_scroll_bar().max_value > game.modal_scroll.size.y, "Short landscape body can scroll rather than overflow")
		game.modal_scroll.scroll_vertical = int(game.modal_scroll.get_v_scroll_bar().max_value)
		await process_frame
		check(inside(game.modal_footer.get_child(0).get_global_rect(), bounds), "Closing stays reachable after body scroll")
		game._close_modal()
		game._show_pause()
		await process_frame
		await process_frame
		check(inside(game.panel.get_global_rect(), bounds), "Pause settings panel fits viewport proxy")
		for button in game.modal_footer.get_children():
			check(inside(button.get_global_rect(), bounds), "Every pause action remains in bounds")
		game._close_modal()
		check(game.subviewport.size != dimensions, "Low-resolution world remains separate from readable UI")
	game.queue_free()
	await process_frame
	print("UI_RESULT ", passed, " passed / ", failed, " failed")
	quit(0 if failed == 0 else 1)
