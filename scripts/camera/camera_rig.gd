class_name CameraRig
extends Camera3D
## Golf camera.
## TEE: behind the ball, looking down the aim line.
## FOLLOW: chases the ball in flight.
## LANDING: hard cut to the landing spot, then tracks the ball as it rolls.
## PUTTING: low and close, used instead of the above when the Putter is selected.

enum Mode { TEE, FOLLOW, LANDING, PUTTING }

signal mode_changed(new_mode: Mode)

@export_group("Tee")
@export var tee_distance: float = 16.0
@export var tee_height: float = 5.5
@export var tee_look_ahead: float = 30.0
@export var tee_smoothing: float = 5.0

@export_group("Follow")
@export var follow_distance: float = 14.0
@export var follow_height: float = 5.0
@export var follow_look_ahead: float = 8.0
@export var follow_smoothing: float = 10.0

@export_group("Landing")
@export var landing_distance: float = 18.0
@export var landing_height: float = 6.0
@export var landing_look_smoothing: float = 8.0

@export_group("Putting")
@export var putt_distance: float = 5.0
@export var putt_height: float = 1.8
@export var putt_look_ahead: float = 10.0

var mode: Mode = Mode.TEE

var _ball: BallPhysics
var _aim: ShotAim
var _putting: bool = false
var _flight_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
var _look: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("camera")
	var listener := get_node_or_null("AudioListener3D") as AudioListener3D
	if listener != null:
		listener.make_current()


## Connect to the nodes whose signals drive the camera.
func bind(ball: BallPhysics, aim: ShotAim, swing: SwingController, input: PlayerInput) -> void:
	_ball = ball
	_aim = aim
	swing.shot_taken.connect(_on_shot_taken)
	ball.ball_landed.connect(_on_ball_landed)
	ball.ball_stopped.connect(_on_ball_stopped)
	input.club_changed.connect(_on_club_changed)
	_putting = input.current_club().is_putter
	snap_to_tee()


## Hard cut to the tee/putting view (new turn, ball replaced, etc.).
func snap_to_tee() -> void:
	if _ball == null:
		return
	_set_mode(Mode.PUTTING if _putting else Mode.TEE)
	global_position = _tee_goal()
	_look = _tee_target()
	look_at(_look)


func _process(delta: float) -> void:
	if _ball == null:
		return
	match mode:
		Mode.TEE, Mode.PUTTING:
			_ease_to(_tee_goal(), _tee_target(), tee_smoothing, tee_smoothing, delta)
		Mode.FOLLOW:
			var v: Vector3 = _ball.linear_velocity
			var flat := Vector3(v.x, 0.0, v.z)
			if flat.length() > 2.0:
				_flight_dir = flat.normalized()
			var dist: float = putt_distance if _putting else follow_distance
			var height: float = putt_height if _putting else follow_height
			var goal: Vector3 = _ball.global_position - _flight_dir * dist + Vector3.UP * height
			var target: Vector3 = _ball.global_position + _flight_dir * follow_look_ahead
			_ease_to(goal, target, follow_smoothing, follow_smoothing, delta)
		Mode.LANDING:
			# Position stays where we cut to; only the aim tracks the rolling ball.
			_look = _look.lerp(_ball.global_position, 1.0 - exp(-landing_look_smoothing * delta))
			look_at(_look)


func _tee_goal() -> Vector3:
	var dir: Vector3 = _aim.get_direction()
	var dist: float = putt_distance if _putting else tee_distance
	var height: float = putt_height if _putting else tee_height
	return _ball.global_position - dir * dist + Vector3.UP * height


func _tee_target() -> Vector3:
	var dir: Vector3 = _aim.get_direction()
	var ahead: float = putt_look_ahead if _putting else tee_look_ahead
	return _ball.global_position + dir * ahead


func _ease_to(goal: Vector3, target: Vector3, pos_rate: float, look_rate: float, delta: float) -> void:
	global_position = global_position.lerp(goal, 1.0 - exp(-pos_rate * delta))
	_look = _look.lerp(target, 1.0 - exp(-look_rate * delta))
	look_at(_look)


func _set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	mode_changed.emit(new_mode)


func _on_shot_taken(_golfer: Node) -> void:
	_flight_dir = _aim.get_direction()
	_set_mode(Mode.FOLLOW)


func _on_ball_landed(_surface: StringName) -> void:
	if _putting:
		return  # Putts stay on the low follow view.
	_set_mode(Mode.LANDING)
	global_position = _ball.global_position - _flight_dir * landing_distance + Vector3.UP * landing_height
	_look = _ball.global_position + _flight_dir * 8.0
	look_at(_look)


func _on_ball_stopped() -> void:
	_set_mode(Mode.PUTTING if _putting else Mode.TEE)


func _on_club_changed(club: Club) -> void:
	_putting = club.is_putter
	if mode == Mode.TEE or mode == Mode.PUTTING:
		_set_mode(Mode.PUTTING if _putting else Mode.TEE)
