class_name ValleyTouchButton
extends Button

# Keep native mouse/keyboard behavior while accepting independent touch fingers.
# Global mouse emulation would let the walking finger monopolize UI input.
const DRAG_SLOP := 12.0
var touch_id := -1
var touch_start := Vector2.ZERO
var touch_moved := false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		if touch_id == -1 and not disabled:
			touch_id = event.index
			touch_start = get_global_transform_with_canvas() * event.position
			touch_moved = false
			set_pressed_no_signal(true)
		accept_event()

func _input(event: InputEvent) -> void:
	if touch_id == -1:
		return
	if event is InputEventScreenDrag and event.index == touch_id:
		if event.position.distance_to(touch_start) > DRAG_SLOP:
			touch_moved = true
			set_pressed_no_signal(false)
	elif event is InputEventScreenTouch and event.index == touch_id and (not event.pressed or event.canceled):
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var activate: bool = not event.canceled and not touch_moved and not disabled and is_visible_in_tree() and Rect2(Vector2.ZERO, size).has_point(local) and event.position.distance_to(touch_start) <= DRAG_SLOP
		cancel_touch()
		if activate:
			pressed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		cancel_touch()

func cancel_touch() -> void:
	touch_id = -1
	touch_moved = false
	set_pressed_no_signal(false)
