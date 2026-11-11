class_name CupDetector
extends Area3D
## Signals when a ball in group "ball" is inside the cup and moving slowly enough to drop.
## Several balls can be holed on one hole; last_ball says which one the latest ball_holed was.

signal ball_holed

## Faster than this (units/s) and the ball skips over the cup.
@export var max_hole_speed: float = 6.0

## The ball that triggered the most recent ball_holed.
var last_ball: BallPhysics = null

var _holed_balls: Array[Node3D] = []


func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		if not body.is_in_group("ball") or _holed_balls.has(body):
			continue
		var rb := body as RigidBody3D
		if rb != null and rb.linear_velocity.length() > max_hole_speed:
			continue
		_holed_balls.append(body)
		last_ball = body as BallPhysics
		ball_holed.emit()


## Call when a new hole/turn begins so the cup can detect again.
func reset() -> void:
	_holed_balls.clear()
	last_ball = null
