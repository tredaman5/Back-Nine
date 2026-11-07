class_name HUDController
extends CanvasLayer
## Minimal debug HUD: club, shot shape, aim, power, and distance to the pin, plus the swing meter.
## Pressure/Focus meters, score, wind and taunts are added in later steps via signals.

const FEET_PER_YARD: float = 3.0

@onready var _club_label: Label = %ClubLabel
@onready var _shape_label: Label = %ShapeLabel
@onready var _power_label: Label = %PowerLabel
@onready var _distance_label: Label = %DistanceLabel
@onready var _result_label: Label = %ResultLabel
@onready var _swing_meter: SwingMeter = $SwingMeter

var _input: PlayerInput
var _aim: ShotAim
var _swing: SwingController
var _ball: BallPhysics
var _pin: Node3D


func bind(input: PlayerInput, aim: ShotAim, swing: SwingController, ball: BallPhysics, pin: Node3D) -> void:
	_input = input
	_aim = aim
	_swing = swing
	_ball = ball
	_pin = pin
	_swing_meter.bind(swing)


## Free text under the main readout (shot results, penalties). Debug use for now.
func set_result(text: String) -> void:
	_result_label.text = text


func _process(_delta: float) -> void:
	if _input == null:
		return
	var club: Club = _input.current_club()
	_club_label.text = "Club: %s (%.0f yd)" % [club.display_name, club.range_yards()]
	_shape_label.text = "Shape: %s   Aim: %.0f deg %s" % [
		String(_input.current_shape()).capitalize().replace("_", " "),
		absf(_aim.yaw_deg),
		"left" if _aim.yaw_deg > 0.5 else ("right" if _aim.yaw_deg < -0.5 else "")]
	_power_label.text = "Power: %.0f%%" % (_swing.power * 100.0)
	var d: Vector2 = Vector2(_ball.global_position.x - _pin.global_position.x, _ball.global_position.z - _pin.global_position.z)
	var yards: float = d.length()
	_distance_label.text = "To pin: %.0f yd (%.0f ft)" % [yards, yards * FEET_PER_YARD]
