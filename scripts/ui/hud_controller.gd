class_name HUDController
extends CanvasLayer
## Match HUD. Top centre: match score, hole and whose turn it is. Top left: strokes and distance
## for each golfer this hole. Top right: green reads. Bottom left: club, shape, power and distance.
## A message box under the scoreboard shows shot results, penalties and the hole/match winner.
## Pressure/Focus meters, wind and taunts are added in later steps via signals.

const FEET_PER_YARD: float = 3.0
## Name colours, in the same order as the golfers list (Dez first).
const GOLFER_COLORS: Array[Color] = [Color(0.5, 0.7, 1.0), Color(1.0, 0.5, 0.45)]

@onready var _score_left: Label = %ScoreLeft
@onready var _score_right: Label = %ScoreRight
@onready var _hole_label: Label = %HoleLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _toast: PanelContainer = %ToastPanel
@onready var _result_label: Label = %ResultLabel
@onready var _row0: Label = %Row0
@onready var _row1: Label = %Row1
@onready var _reads_label: Label = %ReadsLabel
@onready var _club_label: Label = %ClubLabel
@onready var _shape_label: Label = %ShapeLabel
@onready var _power_label: Label = %PowerLabel
@onready var _distance_label: Label = %DistanceLabel
@onready var _swing_meter: SwingMeter = $SwingMeter

var _input: PlayerInput
var _aim: ShotAim
var _swing: SwingController
var _ball: BallPhysics
var _manager: MatchManager


func bind(input: PlayerInput, aim: ShotAim, swing: SwingController, ball: BallPhysics) -> void:
	_input = input
	_aim = aim
	_swing = swing
	_ball = ball
	_swing_meter.bind(swing)


## Show the match score, the hole and each golfer's strokes and distance.
func bind_match(manager: MatchManager) -> void:
	_manager = manager


## Show how many green reads are left this hole.
func bind_reader(reader: GreenReader) -> void:
	reader.reads_changed.connect(_on_reads_changed)
	_on_reads_changed(reader.reads_left)


func _on_reads_changed(reads_left: int) -> void:
	_reads_label.text = "%d / %d  (hold Shift)" % [reads_left, GreenReader.MAX_READS]


## Message under the scoreboard (shot results, penalties, hole and match winners). Empty hides it.
func set_result(text: String) -> void:
	_result_label.text = text
	_toast.visible = text != ""


func _process(_delta: float) -> void:
	if _input == null:
		return
	if _manager != null and _manager.hole != null:
		_update_match(_manager.hole)

	var club: Club = _input.current_club()
	_club_label.text = "%s  (%.0f yd)" % [club.display_name, club.range_yards()]
	_shape_label.text = "Shape: %s    Aim: %.0f deg %s" % [
		String(_input.current_shape()).capitalize().replace("_", " "),
		absf(_aim.yaw_deg),
		"left" if _aim.yaw_deg > 0.5 else ("right" if _aim.yaw_deg < -0.5 else "")]
	_power_label.text = "Power: %.0f%%" % (_swing.power * 100.0)
	if _manager != null and _manager.hole != null:
		var yards: float = _manager.hole.distance_to_pin(_ball.global_position)
		_distance_label.text = "To pin: %.0f yd  (%.0f ft)" % [yards, yards * FEET_PER_YARD]


func _update_match(hole: Hole) -> void:
	var golfers: Array[Golfer] = _manager.golfers
	var scorer: MatchScorer = _manager.scorer

	# Scoreboard: match points on either side, the hole in the middle.
	_score_left.text = "%s  %d" % [golfers[0].display_name.to_upper(), scorer.points.get(golfers[0], 0)]
	_score_right.text = "%d  %s" % [scorer.points.get(golfers[1], 0), golfers[1].display_name.to_upper()]
	_score_left.add_theme_color_override("font_color", GOLFER_COLORS[0])
	_score_right.add_theme_color_override("font_color", GOLFER_COLORS[1])
	_hole_label.text = "HOLE %d / %d   -   %.0f yd   -   %d pt%s" % [
		hole.hole_number, _manager.hole_scenes.size(),
		hole.distance_to_pin(hole.tee_position()), hole.points, "" if hole.points == 1 else "s"]
	_turn_label.text = "%s's turn" % _manager.active.display_name if _manager.active != null else ""

	# This hole: strokes and distance, with a marker on the golfer whose turn it is.
	var rows: Array[Label] = [_row0, _row1]
	for i: int in mini(golfers.size(), rows.size()):
		var golfer: Golfer = golfers[i]
		var status: String
		if scorer.is_holed(golfer):
			status = "holed"
		elif scorer.is_conceded(golfer):
			status = "conceded"
		else:
			status = "%.0f yd" % hole.distance_to_pin(golfer.ball.global_position)
		var marker: String = ">" if golfer == _manager.active else " "
		rows[i].text = "%s %s     %d stroke%s     %s" % [marker, golfer.display_name, scorer.strokes_of(golfer), "" if scorer.strokes_of(golfer) == 1 else "s", status]
		rows[i].add_theme_color_override("font_color", GOLFER_COLORS[i % GOLFER_COLORS.size()])
