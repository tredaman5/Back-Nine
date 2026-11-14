class_name MatchManager
extends Node
## The match referee. Plays the holes in order. On each hole the golfer farthest from the cup
## plays next (ties go to the first golfer in the list, Dez). Spawns one ball per golfer and loads
## each hole scene when its turn comes. Strokes, penalties and points are kept by the MatchScorer child.

signal turn_started(golfer: Golfer)
signal hole_started(hole: Hole)
## result: {winner (Golfer or null), tied (bool), points: {Golfer: int}}
signal match_finished(result: Dictionary)

const TEE_DROP: Vector3 = Vector3(0.0, 0.25, 0.0)
## Pause after a ball stops before the next turn begins.
const SHOT_END_DELAY: float = 0.8
const HOLED_DELAY: float = 1.5
const OOB_DELAY: float = 1.5
## Pause after a hole is finished before the next hole is set up.
const HOLE_END_DELAY: float = 3.0
const MATCH_END_DELAY: float = 8.0

@export var ball_scene: PackedScene
## The holes of the match, in order.
@export var hole_scenes: Array[PackedScene] = []
@export var camera_path: NodePath
@export var golfer_paths: Array[NodePath] = []
## Test setting: start the match over after it finishes. The real game shows result screens instead.
@export var loop_for_testing: bool = true

var hole: Hole
## Zero-based index into hole_scenes of the hole being played.
var hole_index: int = 0
var golfers: Array[Golfer] = []
var active: Golfer

@onready var scorer: MatchScorer = $MatchScorer

var _camera: CameraRig
var _shot_pending: bool = false
var _loaded_index: int = -1
## Bumped whenever a new turn or hole starts so stale timers know to give up.
var _turn_id: int = 0


func _ready() -> void:
	# Let every sibling finish its own _ready first.
	await get_tree().process_frame
	_camera = get_node(camera_path) as CameraRig
	for path: NodePath in golfer_paths:
		golfers.append(get_node(path) as Golfer)

	for golfer: Golfer in golfers:
		var ball := ball_scene.instantiate() as BallPhysics
		get_parent().add_child(ball)
		golfer.set_ball(ball)
		golfer.bind_match(self)
		golfer.shot_taken.connect(_on_shot_taken)
		ball.ball_stopped.connect(_on_ball_stopped.bind(golfer))

	scorer.golfer_conceded.connect(_on_golfer_conceded)
	await get_tree().process_frame
	start_match()


## Reset the match score and begin at the first hole.
func start_match() -> void:
	scorer.reset_match()
	_begin_hole(0)


## Replay the current hole from the tee (strokes for the hole reset).
func restart_hole() -> void:
	_begin_hole(hole_index)


func _begin_hole(index: int) -> void:
	_turn_id += 1
	var id: int = _turn_id
	_shot_pending = false
	active = null
	hole_index = index
	_load_hole(index)

	for golfer: Golfer in golfers:
		var spot: Vector3 = hole.tee_position() + TEE_DROP
		golfer.ball.freeze = false
		golfer.ball.visible = true
		golfer.ball.teleport(spot)
		golfer.rest_position = spot
	# Wait for the teleports to land and for the cup to stop seeing the balls (its overlap list lags).
	for i: int in 30:
		await get_tree().physics_frame
		if id != _turn_id:
			return
		var still_in_cup: bool = false
		for golfer: Golfer in golfers:
			if hole.cup.overlaps_body(golfer.ball):
				still_in_cup = true
		if i >= 1 and not still_in_cup:
			break
	hole.cup.reset()
	scorer.begin_hole(hole, golfers)
	hole_started.emit(hole)
	_next_turn()


## Swap in the scene for hole `index` (the same hole is reused when replaying it).
func _load_hole(index: int) -> void:
	if hole != null and _loaded_index == index:
		return
	if hole != null:
		get_parent().remove_child(hole)
		hole.queue_free()
	hole = hole_scenes[index].instantiate() as Hole
	get_parent().add_child(hole)
	_loaded_index = index
	hole.cup.ball_holed.connect(_on_ball_holed)
	hole.oob.out_of_bounds.connect(_on_out_of_bounds)
	for golfer: Golfer in golfers:
		golfer.hole = hole
		golfer.ball.green_slope = hole.green_slope_at


func _next_turn() -> void:
	_turn_id += 1
	var next: Golfer = null
	var farthest: float = -1.0
	for golfer: Golfer in golfers:
		if scorer.is_done(golfer):
			continue
		var dist: float = hole.distance_to_pin(golfer.ball.global_position)
		if dist > farthest + 0.01:
			next = golfer
			farthest = dist
	if next == null:
		_finish_hole()
		return

	active = next
	next.rest_position = next.ball.global_position
	turn_started.emit(next)
	# After turn_started so an AI golfer has already chosen its club (putting camera or not).
	_camera.set_subject(next)


func _finish_hole() -> void:
	active = null
	var id: int = _turn_id
	await get_tree().create_timer(HOLE_END_DELAY).timeout
	if id != _turn_id:
		return
	if hole_index + 1 < hole_scenes.size():
		_begin_hole(hole_index + 1)
	else:
		_finish_match()


func _finish_match() -> void:
	var winner: Golfer = null
	var best: int = -1
	var tied: bool = false
	for golfer: Golfer in golfers:
		var pts: int = scorer.points.get(golfer, 0)
		if pts > best:
			best = pts
			winner = golfer
			tied = false
		elif pts == best:
			tied = true
	if tied:
		winner = null
	match_finished.emit({"winner": winner, "tied": tied, "points": scorer.points.duplicate()})
	if loop_for_testing:
		var id: int = _turn_id
		await get_tree().create_timer(MATCH_END_DELAY).timeout
		if id == _turn_id:
			start_match()


func _end_shot(golfer: Golfer, delay: float) -> void:
	_shot_pending = false
	var id: int = _turn_id
	await get_tree().create_timer(delay).timeout
	if id != _turn_id:
		return
	scorer.resolve_shot(golfer)
	_next_turn()


func _golfer_of(ball: BallPhysics) -> Golfer:
	for golfer: Golfer in golfers:
		if golfer.ball == ball:
			return golfer
	return null


func _on_shot_taken(golfer: Golfer) -> void:
	if golfer == active:
		_shot_pending = true


func _on_ball_stopped(golfer: Golfer) -> void:
	if golfer != active or not _shot_pending or scorer.is_done(golfer):
		return
	_end_shot(golfer, SHOT_END_DELAY)


func _on_ball_holed() -> void:
	var golfer: Golfer = _golfer_of(hole.cup.last_ball)
	if golfer == null:
		return
	_remove_ball(golfer)
	if golfer == active and _shot_pending:
		_end_shot(golfer, HOLED_DELAY)


func _on_golfer_conceded(golfer: Golfer) -> void:
	_remove_ball(golfer)


## Take a ball out of play (it is in the cup, or its golfer conceded the hole).
func _remove_ball(golfer: Golfer) -> void:
	golfer.ball.freeze = true
	golfer.ball.visible = false
	golfer.ball.in_flight = false


func _on_out_of_bounds() -> void:
	var golfer: Golfer = _golfer_of(hole.oob.last_ball)
	if golfer == null or golfer != active or not _shot_pending:
		return
	_shot_pending = false
	var id: int = _turn_id
	await get_tree().create_timer(OOB_DELAY).timeout
	if id != _turn_id:
		return
	# Replace the ball where it was hit from (MatchScorer adds the stroke penalty).
	golfer.ball.teleport(golfer.rest_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if id != _turn_id:
		return
	scorer.resolve_shot(golfer)
	_next_turn()
