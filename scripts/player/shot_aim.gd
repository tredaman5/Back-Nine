class_name ShotAim
extends Node3D
## Rotates the aim direction (mouse, arrow keys or left stick) and draws a dashed aim line
## from the ball, as long as the selected club's range. Positive yaw aims left.

signal aim_changed(yaw_deg: float)

const LINE_SHADER: Shader = preload("res://assets/shaders/aim_line.gdshader")

@export var player_input_path: NodePath = ^"../PlayerInput"
@export var max_yaw_deg: float = 75.0
## Turn rate for keyboard / stick, degrees per second.
@export var turn_speed_deg: float = 60.0
## Mouse at the screen edge aims this many degrees off center.
@export var mouse_range_deg: float = 45.0
@export var line_width: float = 0.5

var yaw_deg: float = 0.0

var _input: PlayerInput
var _ball: BallPhysics
var _line: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_input = get_node(player_input_path) as PlayerInput
	_input.mouse_aimed.connect(_on_mouse_aimed)
	_input.club_changed.connect(_on_club_changed)

	_material = ShaderMaterial.new()
	_material.shader = LINE_SHADER
	_line = get_node("AimLine") as MeshInstance3D
	_line.material_override = _material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# PlayerInput is an earlier sibling, so its club list already exists.
	_on_club_changed(_input.current_club())


func set_ball(ball: BallPhysics) -> void:
	_ball = ball


## Unit horizontal direction the shot will go.
func get_direction() -> Vector3:
	return Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))


func aim_at(point: Vector3) -> void:
	if _ball == null:
		return
	var d: Vector3 = point - _ball.global_position
	set_yaw(rad_to_deg(atan2(-d.x, -d.z)))


func set_yaw(deg: float) -> void:
	yaw_deg = clampf(deg, -max_yaw_deg, max_yaw_deg)
	rotation.y = deg_to_rad(yaw_deg)
	aim_changed.emit(yaw_deg)


func _process(delta: float) -> void:
	if _ball == null:
		return
	visible = _input.enabled and not _ball.in_flight
	global_position = _ball.global_position - Vector3(0.0, 0.15, 0.0)
	if not _input.enabled:
		return
	var axis: float = _input.get_aim_axis()
	if absf(axis) > 0.01:
		set_yaw(yaw_deg + axis * turn_speed_deg * delta)


func _on_mouse_aimed(norm_x: float) -> void:
	set_yaw(-norm_x * mouse_range_deg)


func _on_club_changed(club: Club) -> void:
	var length: float = maxf(club.range_yards(), 5.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(line_width, length)
	_line.mesh = plane
	_line.position = Vector3(0.0, 0.0, -length * 0.5)
	_material.set_shader_parameter("line_length", length)
