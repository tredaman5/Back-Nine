class_name OOBDetector
extends Area3D
## Signals when a ball in group "ball" enters this out-of-bounds (or water) volume.
## last_ball says which ball triggered the most recent out_of_bounds.

signal out_of_bounds

var last_ball: BallPhysics = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("ball"):
		last_ball = body as BallPhysics
		out_of_bounds.emit()
