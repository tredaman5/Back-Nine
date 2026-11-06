extends Node
## TEMPORARY test harness for the player and ball. Replaced by MatchManager and the real HUD later.
## Spawns the ball, hooks up the swing meter, shows results, and handles out-of-bounds / holed.
## R = reset to tee.

@export var ball_scene: PackedScene
@export var tee_path: NodePath
@export var cup_path: NodePath
@export var oob_path: NodePath
@export var camera_path: NodePath
@export var player_path: NodePath

var _ball: BallPhysics
var _tee: Marker3D
var _cup: CupDetector
var _oob: OOBDetector
var _camera: Camera3D
var _input: PlayerInput
var _aim: ShotAim
var _swing: SwingController
var _label: Label
var _result: String = ""
var _follow: bool = false
var _rest_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_tee = get_node(tee_path) as Marker3D
	_cup = get_node(cup_path) as CupDetector
	_oob = get_node(oob_path) as OOBDetector
	_camera = get_node(camera_path) as Camera3D
	var player: Node = get_node(player_path)
	_input = player.get_node("PlayerInput") as PlayerInput
	_aim = player.get_node("ShotAim") as ShotAim
	_swing = player.get_node("SwingController") as SwingController

	_ball = ball_scene.instantiate() as BallPhysics
	get_parent().add_child.call_deferred(_ball)
	await get_tree().process_frame
	_ball.ball_landed.connect(_on_landed)
	_ball.ball_stopped.connect(_on_stopped)
	_cup.ball_holed.connect(_on_holed)
	_oob.out_of_bounds.connect(_on_oob)
	_swing.swing_resolved.connect(_on_swing_resolved)
	_swing.shot_taken.connect(_on_shot_taken)
	_aim.set_ball(_ball)
	_swing.set_ball(_ball)
	_reset_ball(_tee.global_position + Vector3(0, 0.25, 0))

	var layer := CanvasLayer.new()
	var meter := SwingMeter.new()
	meter.bind(_swing)
	layer.add_child(meter)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	layer.add_child(_label)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		_reset_ball(_tee.global_position + Vector3(0, 0.25, 0))


func _reset_ball(pos: Vector3) -> void:
	_ball.teleport(pos)
	_rest_position = pos
	_swing.reset()
	_follow = false
	_result = ""
	_camera.global_position = pos + Vector3(0, 6, 18)
	_camera.rotation_degrees = Vector3(-10, 0, 0)
	_aim.aim_at(_cup.global_position)


func _on_shot_taken(_golfer: Node) -> void:
	_result = "In flight..."
	_follow = true


func _on_swing_resolved(r: Dictionary) -> void:
	var how: String = "perfect" if r["centered"] else ("in window" if r["in_window"] else ("SLICE" if r["error"] > 0.0 else "HOOK"))
	_result = "Power %.0f%%  |  %s" % [r["power"] * 100.0, how]


func _on_landed(surface: StringName) -> void:
	_result += "\nCarry %.1f yd (landed on %s)" % [_ball.carry_distance(), surface]


func _on_stopped() -> void:
	_result += "\nStopped: total %.1f yd" % _ball.total_distance()
	_rest_position = _ball.global_position
	_aim.aim_at(_cup.global_position)


func _on_holed() -> void:
	_result += "\nHOLED!"
	await get_tree().create_timer(2.0).timeout
	_reset_ball(_tee.global_position + Vector3(0, 0.25, 0))
	_cup.reset()


func _on_oob() -> void:
	_result += "\nOut of bounds (+1 stroke). Replacing ball."
	await get_tree().create_timer(1.5).timeout
	_reset_ball(_rest_position)


func _process(_delta: float) -> void:
	if _follow:
		_camera.global_position = _ball.global_position + Vector3(0, 6, 18)
		_camera.look_at(_ball.global_position + Vector3(0, 0, -20))
	if _label != null:
		var club: Club = _input.current_club()
		var to_pin: float = Vector2(_ball.global_position.x - _cup.global_position.x, _ball.global_position.z - _cup.global_position.z).length()
		_label.text = "%s (%.0f yd)  |  %s  |  aim %.0f deg left  |  pin %.0f yd\n%s\n[hold LMB + drag down] power, release  >  [LMB] stop marker in green    [R] reset  [Q/E] club  [1-3] shape" % [
			club.display_name, club.range_yards(), _input.current_shape(), _aim.yaw_deg, to_pin, _result]
