extends Node
## TEMPORARY debug glue for the test course. Spawns the HUD, binds it to Dez, and writes shot
## results under the HUD. Replaced by the real match UI (scoring HUD) later.
## R = restart the hole.

@export var hud_scene: PackedScene
@export var manager_path: NodePath
@export var player_path: NodePath

var _manager: MatchManager
var _hud: HUDController
var _result: String = ""


func _ready() -> void:
	_manager = get_node(manager_path) as MatchManager
	_manager.hole_started.connect(_on_hole_started)
	_manager.turn_started.connect(_on_turn_started)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		_manager.start_hole()


func _on_hole_started(hole: Hole) -> void:
	if _hud != null:
		return
	var player := get_node(player_path) as Player
	_hud = hud_scene.instantiate() as HUDController
	add_child(_hud)
	_hud.bind(
		player.get_node("PlayerInput") as PlayerInput,
		player.get_node("ShotAim") as ShotAim,
		player.get_node("SwingController") as SwingController,
		player.ball,
		hole.cup)
	_hud.bind_match(_manager, hole)

	(player.get_node("SwingController") as SwingController).swing_resolved.connect(_on_swing_resolved)
	for golfer: Golfer in _manager.golfers:
		golfer.shot_taken.connect(_on_shot_taken)
		golfer.ball.ball_landed.connect(_on_landed.bind(golfer))
		golfer.ball.ball_stopped.connect(_on_stopped.bind(golfer))
	hole.cup.ball_holed.connect(_on_holed)
	hole.oob.out_of_bounds.connect(_on_oob)


func _set_result(text: String) -> void:
	_result = text
	if _hud != null:
		_hud.set_result(text)


func _on_turn_started(golfer: Golfer) -> void:
	_set_result("%s's shot" % golfer.display_name)


func _on_swing_resolved(r: Dictionary) -> void:
	var how: String = "perfect" if r["centered"] else ("in window" if r["in_window"] else ("SLICE" if r["error"] > 0.0 else "HOOK"))
	_set_result("Dez  |  Power %.0f%%  |  %s" % [r["power"] * 100.0, how])


func _on_shot_taken(golfer: Golfer) -> void:
	_set_result(_result + "\n%s: in flight..." % golfer.display_name)


func _on_landed(surface: StringName, golfer: Golfer) -> void:
	_set_result(_result + "\n%s carry %.1f yd (landed on %s)" % [golfer.display_name, golfer.ball.carry_distance(), surface])


func _on_stopped(golfer: Golfer) -> void:
	_set_result(_result + "\n%s stopped: total %.1f yd" % [golfer.display_name, golfer.ball.total_distance()])


func _on_holed() -> void:
	var ball: BallPhysics = _manager.hole.cup.last_ball
	for golfer: Golfer in _manager.golfers:
		if golfer.ball == ball:
			_set_result(_result + "\n%s HOLED!" % golfer.display_name)


func _on_oob() -> void:
	_set_result(_result + "\nOut of bounds. Replacing ball.")
