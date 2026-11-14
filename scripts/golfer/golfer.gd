class_name Golfer
extends Node3D
## Base class for anything that takes shots in a match: Dez (Player) and the bosses (Opponent).
## MatchManager gives each golfer its own ball and announces whose turn it is with turn_started.

signal shot_taken(golfer: Golfer)
## Emitted when the golfer switches to or from the putter, so the camera can follow suit.
signal putting_changed(putting: bool)

## How far (yards) the golfer's body stands to the right of the ball.
const STAND_OFFSET: float = 1.4

@export var display_name: String = "Golfer"
## Which side of the ball the body stands on: 1 = right of the aim line, -1 = left.
@export var stand_side: float = 1.0

var ball: BallPhysics
var hole: Hole
## Where the ball lay before the current shot. An out-of-bounds ball is replaced here.
var rest_position: Vector3 = Vector3.ZERO


func set_ball(new_ball: BallPhysics) -> void:
	ball = new_ball


## Hook up to the match referee.
func bind_match(manager: MatchManager) -> void:
	manager.turn_started.connect(_on_turn_started)


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


func _on_turn_started(golfer: Golfer) -> void:
	if golfer == self:
		begin_turn()
	else:
		end_turn()


# The body stands beside the ball while it is at rest and stays put while the ball is in flight.
func _process(_delta: float) -> void:
	if ball == null or hole == null or ball.in_flight:
		return
	var to_pin: Vector3 = hole.pin_position() - ball.global_position
	to_pin.y = 0.0
	var forward: Vector3 = to_pin.normalized() if to_pin.length() > 0.1 else Vector3(0.0, 0.0, -1.0)
	var right: Vector3 = forward.cross(Vector3.UP)
	global_position = ball.global_position - Vector3(0.0, 0.2, 0.0) + right * STAND_OFFSET * stand_side
