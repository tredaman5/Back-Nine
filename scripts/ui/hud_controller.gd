class_name HUDController
extends CanvasLayer
## Minimal debug HUD: club, shot shape, aim, power, and distance to the pin, plus the swing meter.
## Pressure/Focus meters, score, wind and taunts are added in later steps via signals.

const FEET_PER_YARD: float = 3.0

@onready var _reads_label: Label = %ReadsLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _match_label: Label = %MatchLabel
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
var _manager: MatchManager
var _hole: Hole
var _turn_name: String = ""


func bind(input: PlayerInput, aim: ShotAim, swing: SwingController, ball: BallPhysics, pin: Node3D) -> void:
	_input = input
	_aim = aim
	_swing = swing
	_ball = ball
	_pin = pin
	_swing_meter.bind(swing)


## Show whose turn it is and how far each golfer's ball is from the pin.
func bind_match(manager: MatchManager, hole: Hole) -> void:
	_manager = manager
	_hole = hole
	manager.turn_started.connect(_on_turn_started)


## Show how many green reads are left this hole.
func bind_reader(reader: GreenReader) -> void:
	reader.reads_changed.connect(_on_reads_changed)
	_on_reads_changed(reader.reads_left)


func _on_reads_changed(reads_left: int) -> void:
	_reads_label.text = "Green reads: %d / %d  (hold Shift)" % [reads_left, GreenReader.MAX_READS]


func _on_turn_started(golfer: Golfer) -> void:
	_turn_name = golfer.display_name


## Free text under the main readout (shot results, penalties). Debug use for now.
func set_result(text: String) -> void:
	_result_label.text = text


func _process(_delta: float) -> void:
	if _input == null:
		return
	if _manager != null:
		var parts: PackedStringArray = []
		var score: PackedStringArray = []
		for golfer: Golfer in _manager.golfers:
			var status: String = "holed" if _manager.scorer.is_holed(golfer) else ("conceded" if _manager.scorer.is_conceded(golfer) else "%.0f yd" % _hole.distance_to_pin(golfer.ball.global_position))
			parts.append("%s %s, %d strokes" % [golfer.display_name, status, _manager.scorer.strokes_of(golfer)])
			score.append("%s %d" % [golfer.display_name, _manager.scorer.points.get(golfer, 0)])
		_match_label.text = "Turn: %s   |   %s" % [_turn_name, "   ".join(parts)]
		_score_label.text = "Hole %d (%d pt)   Match: %s" % [_hole.hole_number, _hole.points, "   ".join(score)]
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
