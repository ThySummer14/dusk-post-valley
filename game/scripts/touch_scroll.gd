class_name ValleyTouchScroll
extends ScrollContainer

# Native ScreenTouch/ScreenDrag scrolling without monopolizing other fingers.
const DRAG_SLOP := 12.0
var touch_id := -1
var touch_start := Vector2.ZERO
var scroll_start := 0
var dragging := false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		if touch_id == -1:
			touch_id = event.index
			touch_start = get_global_transform_with_canvas() * event.position
			scroll_start = scroll_vertical
			dragging = false
		accept_event()

func _input(event: InputEvent) -> void:
	if touch_id == -1:
		return
	if event is InputEventScreenDrag and event.index == touch_id:
		var distance: float = touch_start.y - event.position.y
		if absf(distance) > DRAG_SLOP:
			dragging = true
		if dragging:
			scroll_vertical = scroll_start + roundi(distance)
	elif event is InputEventScreenTouch and event.index == touch_id and (not event.pressed or event.canceled):
		cancel_touch()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		cancel_touch()

func cancel_touch() -> void:
	touch_id = -1
	dragging = false
