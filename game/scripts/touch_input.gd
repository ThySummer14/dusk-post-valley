class_name ValleyTouch
extends RefCounted
var pointer := -1
var origin := Vector2.ZERO
var axis := Vector2.ZERO
const RADIUS := 68.0

func press(id: int, position: Vector2, allowed: bool) -> bool:
	if not allowed or pointer != -1:
		return false
	pointer = id
	origin = position
	axis = Vector2.ZERO
	return true

func drag(id: int, position: Vector2) -> void:
	if id != pointer:
		return
	var delta := (position - origin) / RADIUS
	axis = delta.limit_length(1.0) if delta.length() > 0.14 else Vector2.ZERO

func release(id: int) -> void:
	if id == pointer:
		cancel()

func cancel() -> void:
	pointer = -1
	axis = Vector2.ZERO
