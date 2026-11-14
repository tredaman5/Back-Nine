class_name Golfer
extends Node3D
## Base class for anything that takes shots in a match: Dez (Player) and the bosses (Opponent).
## MatchManager gives each golfer its own ball and announces whose turn it is with turn_started.
## A golfer's Body child (GolferBody) stands beside the ball and plays the swing animations.

signal shot_taken(golfer: Golfer)
## Emitted when the golfer switches to or from the putter, so the camera can follow suit.
signal putting_changed(putting: bool)

## How far (yards) the golfer's body stands to the right of the ball.
const STAND_OFFSET: float = 1.4
## Seconds from the start of the swing animation to the club meeting the ball.
const IMPACT_DELAY: float = 0.12

@export var display_name: String = "Golfer"
## Which side of the ball the body stands on: 1 = right of the aim line, -1 = left.
@export var stand_side: float = 1.0

var ball: BallPhysics
var hole: Hole
## Where the ball lay before the current shot. An out-of-bounds ball is replaced here.
var rest_position: Vector3 = Vector3.ZERO

@onready var body: GolferBody = get_node_or_null("Body") as GolferBody


func set_ball(new_ball: BallPhysics) -> void:
	ball = new_ball


## Hook up to the match referee.
func bind_match(manager: MatchManager) -> void:
	manager.turn_started.connect(_on_turn_started)
	manager.scorer.hole_finished.connect(_on_hole_finished)


## Unit horizontal direction the next shot will go. Subclasses override.
func aim_direction() -> Vector3:
	return Vector3(0.0, 0.0, -1.0)


func is_putting() -> bool:
	return false


## Called when it becomes this golfer's turn. Subclasses override.
func begin_turn() -> void:
	pass


## Called when it becomes someone else's turn. Subclasses override.
func end_turn() -> void:
	pass


## Raise the club (swing meter stage 2, or the boss's wind-up).
func show_backswing() -> void:
	if body != null:
		body.play_backswing(is_putting())


## Swing through the ball and play the swing and contact sounds.
func show_swing() -> void:
	var putting: bool = is_putting()
	if body != null:
		body.play_swing(putting)
	_play_sfx(&"swing", -3.0 if putting else 0.0)
	await get_tree().create_timer(IMPACT_DELAY).timeout
	_play_sfx(&"putt" if putting else &"impact", 0.0)


## Play a sound through the AudioManager autoload (looked up at runtime, so tools that run
## scripts without autoloads still work).
func _play_sfx(sfx: StringName, volume_db: float) -> void:
	var audio: Node = get_node_or_null(^"/root/AudioManager")
	if audio != null:
		audio.call(&"play_sfx", sfx, volume_db)


func _on_turn_started(golfer: Golfer) -> void:
	if golfer == self:
		if body != null:
			body.play_anim(&"idle")
		begin_turn()
	else:
		end_turn()


func _on_hole_finished(result: Dictionary) -> void:
	if body == null:
		return
	var winner: Golfer = result["winner"]
	if winner == self:
		body.play_anim(&"celebrate")
	elif winner != null:
		body.play_anim(&"disappointed")


# The body stands beside the ball while it is at rest and stays put while the ball is in flight.
func _process(_delta: float) -> void:
	if ball == null or hole == null or ball.in_flight:
		return
	var to_pin: Vector3 = hole.pin_position() - ball.global_position
	to_pin.y = 0.0
	var forward: Vector3 = to_pin.normalized() if to_pin.length() > 0.1 else Vector3(0.0, 0.0, -1.0)
	var right: Vector3 = forward.cross(Vector3.UP)
	global_position = ball.global_position - Vector3(0.0, 0.2, 0.0) + right * STAND_OFFSET * stand_side
	if body != null:
		# Face the ball and swing along the aim line. A body on the left side is mirrored.
		var aim: Vector3 = aim_direction()
		body.rotation.y = atan2(-aim.z, aim.x) if stand_side >= 0.0 else atan2(aim.z, -aim.x)
		body.scale.x = 1.0 if stand_side >= 0.0 else -1.0
