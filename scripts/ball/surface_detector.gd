class_name SurfaceDetector
extends RayCast3D
## Reports the surface under the ball by reading the "surface" metadata on the ground body.
## Returns &"air" when nothing is below the ball.

const AIR: StringName = &"air"
const DEFAULT_SURFACE: StringName = &"rough"

var _ball: Node3D


func _ready() -> void:
	_ball = get_parent() as Node3D
	top_level = true  # Don't spin with the ball.
	enabled = true
	target_position = Vector3(0.0, -0.6, 0.0)
	collision_mask = 1  # World layer only.


func get_surface() -> StringName:
	global_transform = Transform3D(Basis.IDENTITY, _ball.global_position)
	force_raycast_update()
	if not is_colliding():
		return AIR
	var collider := get_collider() as Node
	if collider == null:
		return DEFAULT_SURFACE
	return StringName(collider.get_meta("surface", DEFAULT_SURFACE))
