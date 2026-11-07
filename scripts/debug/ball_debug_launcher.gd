extends Node
## TEMPORARY test harness for the player and ball. Replaced by MatchManager later.
## Spawns the ball and HUD, hooks up the camera, shows shot results, and handles out-of-bounds / holed.
## R = reset to tee.

@export var ball_scene: PackedScene
@export var hud_scene: PackedScene
@export var tee_path: NodePath
@export var cup_path: NodePath
@export var oob_path: NodePath
@export var camera_path: NodePath
@export var player_path: NodePath

var _ball: BallPhysics
var _tee: Marker3D
var _cup: CupDetector
var _oob: OOBDetector
var _camera: CameraRig
var _hud: HUDController
var _aim: ShotAim
var _swing: SwingController
var _result: String = ""
var _rest_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_tee = get_node(tee_path) as Marker3D
	_cup = get_node(cup_path) as CupDetector
	_oob = get_node(oob_path) as OOBDetector
	_camera = get_node(camera_path) as CameraRig
	var player: Node = get_node(player_path)
	var input := player.get_node("PlayerInput") as PlayerInput
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
	_camera.bind(_ball, _aim, _swing, input)

	_hud = hud_scene.instantiate() as HUDController
	add_child(_hud)
	_hud.bind(input, _aim, _swing, _ball, _cup)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		_reset_ball(_tee.global_position + Vector3(0, 0.25, 0))


func _reset_ball(pos: Vector3) -> void:
	_ball.teleport(pos)
	_rest_position = pos
	_swing.reset()
	_aim.aim_at(_cup.global_position)
	_set_result("")
	if _camera != null:
		_camera.snap_to_tee()


func _set_result(text: String) -> void:
	_result = text
	if _hud != null:
		_hud.set_result(text)


func _on_shot_taken(_golfer: Node) -> void:
	_set_result("In flight...")


func _on_swing_resolved(r: Dictionary) -> void:
	var how: String = "perfect" if r["centered"] else ("in window" if r["in_window"] else ("SLICE" if r["error"] > 0.0 else "HOOK"))
	_set_result("Power %.0f%%  |  %s" % [r["power"] * 100.0, how])


func _on_landed(surface: StringName) -> void:
	_set_result(_result + "\nCarry %.1f yd (landed on %s)" % [_ball.carry_distance(), surface])


func _on_stopped() -> void:
	_set_result(_result + "\nStopped: total %.1f yd" % _ball.total_distance())
	_rest_position = _ball.global_position
	_aim.aim_at(_cup.global_position)


func _on_holed() -> void:
	_set_result(_result + "\nHOLED!")
	await get_tree().create_timer(2.0).timeout
	_reset_ball(_tee.global_position + Vector3(0, 0.25, 0))
	_cup.reset()


func _on_oob() -> void:
	_set_result(_result + "\nOut of bounds (+1 stroke). Replacing ball.")
	await get_tree().create_timer(1.5).timeout
	_reset_ball(_rest_position)
