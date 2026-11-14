class_name MatchScorer
extends Node
## Counts strokes and decides each hole.
## - Every shot is a stroke. Out of bounds adds one more stroke (MatchManager replaces the ball).
## - A golfer who has used MAX_STROKES without holing out concedes the hole.
## - Fewer strokes wins the hole's points; equal strokes halve the hole (no points).

## Points per golfer for the whole match.
signal score_changed(points: Dictionary)
## result: {hole, winner (Golfer or null), halved, points, strokes: {Golfer: int}, conceded: {Golfer: bool}}
signal hole_finished(result: Dictionary)
signal golfer_conceded(golfer: Golfer)

const MAX_STROKES: int = 8
## Stroke total used to compare a golfer who conceded; worse than any real score.
const CONCEDED_SCORE: int = 99

var points: Dictionary[Golfer, int] = {}

var _hole: Hole
var _golfers: Array[Golfer] = []
var _strokes: Dictionary[Golfer, int] = {}
var _holed: Dictionary[Golfer, bool] = {}
var _conceded: Dictionary[Golfer, bool] = {}
var _finished: bool = false


## New match: everyone's points go back to zero.
func reset_match() -> void:
	points.clear()


## Start counting a fresh hole. Match points carry over between holes.
func begin_hole(hole: Hole, golfers: Array[Golfer]) -> void:
	if is_instance_valid(_hole):
		_hole.cup.ball_holed.disconnect(_on_ball_holed)
		_hole.oob.out_of_bounds.disconnect(_on_out_of_bounds)
	_hole = hole
	_golfers = golfers
	_finished = false
	_strokes.clear()
	_holed.clear()
	_conceded.clear()
	for golfer: Golfer in golfers:
		_strokes[golfer] = 0
		if not points.has(golfer):
			points[golfer] = 0
		if not golfer.shot_taken.is_connected(_on_shot_taken):
			golfer.shot_taken.connect(_on_shot_taken)
	hole.cup.ball_holed.connect(_on_ball_holed)
	hole.oob.out_of_bounds.connect(_on_out_of_bounds)
	score_changed.emit(points)


func strokes_of(golfer: Golfer) -> int:
	return _strokes.get(golfer, 0)


func is_holed(golfer: Golfer) -> bool:
	return _holed.get(golfer, false)


func is_conceded(golfer: Golfer) -> bool:
	return _conceded.get(golfer, false)


## A golfer is done with the hole once they have holed out or conceded.
func is_done(golfer: Golfer) -> bool:
	return is_holed(golfer) or is_conceded(golfer)


## MatchManager calls this when a shot has finished (ball stopped, holed, or replaced after OOB).
func resolve_shot(golfer: Golfer) -> void:
	if _finished or is_done(golfer):
		return
	if strokes_of(golfer) >= MAX_STROKES:
		_conceded[golfer] = true
		golfer_conceded.emit(golfer)
		_check_hole_done()


func _on_shot_taken(golfer: Golfer) -> void:
	if _finished or is_done(golfer):
		return
	_strokes[golfer] += 1


func _on_out_of_bounds() -> void:
	var golfer: Golfer = _golfer_of(_hole.oob.last_ball)
	if golfer == null or _finished or is_done(golfer):
		return
	_strokes[golfer] += 1


func _on_ball_holed() -> void:
	var golfer: Golfer = _golfer_of(_hole.cup.last_ball)
	if golfer == null or _finished or is_done(golfer):
		return
	_holed[golfer] = true
	_check_hole_done()


func _check_hole_done() -> void:
	if _finished:
		return
	for golfer: Golfer in _golfers:
		if not is_done(golfer):
			return
	_finished = true

	var winner: Golfer = null
	var best: int = CONCEDED_SCORE + 1
	var tied: bool = false
	for golfer: Golfer in _golfers:
		var score: int = CONCEDED_SCORE if is_conceded(golfer) else strokes_of(golfer)
		if score < best:
			best = score
			winner = golfer
			tied = false
		elif score == best:
			tied = true
	if tied:
		winner = null

	var earned: int = 0
	if winner != null:
		earned = _hole.points
		points[winner] += earned
	var result: Dictionary = {
		"hole": _hole.hole_number,
		"winner": winner,
		"halved": winner == null,
		"points": earned,
		"strokes": _strokes.duplicate(),
		"conceded": _conceded.duplicate(),
	}
	score_changed.emit(points)
	hole_finished.emit(result)


func _golfer_of(ball: BallPhysics) -> Golfer:
	for golfer: Golfer in _golfers:
		if golfer.ball == ball:
			return golfer
	return null
