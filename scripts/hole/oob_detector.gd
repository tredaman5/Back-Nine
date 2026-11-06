class_name OOBDetector
extends Area3D
## Signals when a ball in group "ball" enters this out-of-bounds (or water) volume.

signal out_of_bounds


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("ball"):
		out_of_bounds.emit()
