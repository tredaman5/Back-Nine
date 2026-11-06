class_name CupDetector
extends Area3D
## Signals when a ball in group "ball" is inside the cup and moving slowly enough to drop.

signal ball_holed

## Faster than this (units/s) and the ball skips over the cup.
@export var max_hole_speed: float = 6.0

var _holed: bool = false


func _physics_process(_delta: float) -> void:
	if _holed:
		return
	for body: Node3D in get_overlapping_bodies():
		if not body.is_in_group("ball"):
			continue
		var rb := body as RigidBody3D
		if rb != null and rb.linear_velocity.length() > max_hole_speed:
			continue
		_holed = true
		ball_holed.emit()
		return


## Call when a new hole/turn begins so the cup can detect again.
func reset() -> void:
	_holed = false
