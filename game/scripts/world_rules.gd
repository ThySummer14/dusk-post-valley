class_name ValleyRules
extends RefCounted
const START := Vector2(-8.0, 7.0)
const RADIUS := 0.28
var obstacles: Array[Rect2] = []

static func height_at(p: Vector2) -> float:
	# Back of the valley rises as a broad continuous walkable slope.
	return clampf((-p.y - 2.0) * 0.22, 0.0, 1.65)

func can_walk(p: Vector2) -> bool:
	if p.x < -13.6 or p.x > 13.6 or p.y < -11.5 or p.y > 11.4:
		return false
	# Creek crossed at the timber bridge; water is never an invisible pit.
	if p.x > 2.75 and p.x < 5.65 and absf(p.y - 2.0) > 1.2:
		return false
	for rect in obstacles:
		if rect.grow(RADIUS).has_point(p):
			return false
	return true

func move(from: Vector2, displacement: Vector2) -> Vector2:
	# Substeps prevent collision tunnelling even on a slow frame.
	var steps := maxi(1, ceili(displacement.length() / 0.12))
	var delta := displacement / float(steps)
	var p := from
	for step in range(steps):
		var px := p + Vector2(delta.x, 0)
		if can_walk(px):
			p = px
		var py := p + Vector2(0, delta.y)
		if can_walk(py):
			p = py
	return p
