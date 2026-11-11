class_name OpponentAI
extends Node
## Plans and takes the boss's shots: picks a club and aim, then adds random error.
## This is the first version (distance-based club pick, random aim/power error). It will be
## replaced by the shared shot planner that Bo's Caddie Call also uses.

signal shot_taken(golfer: Node)

## Seconds the boss "thinks" before swinging, so the camera can show the setup.
@export var think_time: float = 1.2
## Aim error on full shots, standard deviation in degrees. Putts use a quarter of it.
@export var aim_error_deg: float = 2.0
## Power error, standard deviation as a fraction of full power.
@export var power_error: float = 0.03

var club: Club
var power: float = 0.0
var aim_direction: Vector3 = Vector3(0.0, 0.0, -1.0)

var _ball: BallPhysics
var _hole: Hole
var _bag: Array[Club] = Club.standard_bag()
var _token: int = 0


func set_ball(ball: BallPhysics) -> void:
	_ball = ball


func is_putting() -> bool:
	return club != null and club.is_putter


## Plan the shot right away (so the camera sees the aim), then swing after think_time.
func take_turn(hole: Hole) -> void:
	_hole = hole
	_token += 1
	var token: int = _token
	_plan()
	await get_tree().create_timer(think_time).timeout
	if token != _token:
		return
	_execute()


func _plan() -> void:
	var to_pin: Vector3 = _hole.pin_position() - _ball.global_position
	to_pin.y = 0.0
	var dist: float = to_pin.length()
	aim_direction = to_pin.normalized() if dist > 0.01 else Vector3(0.0, 0.0, -1.0)
	var surface: StringName = _ball.current_surface()

	if surface == &"green":
		club = _putter()
		power = clampf(dist / club.putt_range_yards, 0.05, 1.0)
		return

	var lie: float = SwingController.LIE_POWER.get(surface, 1.0)
	club = _pick_flight_club(dist, lie)
	power = clampf(dist / (club.carry_yards * lie), 0.1, 1.0)


## The shortest flight club that reaches the pin from this lie, or the longest club if none does.
func _pick_flight_club(dist: float, lie: float) -> Club:
	var longest: Club = null
	for i: int in range(_bag.size() - 1, -1, -1):
		var c: Club = _bag[i]
		if c.is_putter:
			continue
		if c.carry_yards * lie >= dist:
			return c
		longest = c
	return longest


func _putter() -> Club:
	for c: Club in _bag:
		if c.is_putter:
			return c
	return _bag[0]


func _execute() -> void:
	var yaw_error: float = randfn(0.0, aim_error_deg * (0.25 if club.is_putter else 1.0))
	var dir: Vector3 = aim_direction.rotated(Vector3.UP, deg_to_rad(yaw_error))
	var shot_power: float = clampf(power + randfn(0.0, power_error), 0.05, 1.0)
	var surface: StringName = _ball.current_surface()
	var speed: float
	if club.is_putter:
		speed = BallPhysics.launch_speed_for_putt(club.putt_range_yards * shot_power, surface)
	else:
		var lie: float = SwingController.LIE_POWER.get(surface, 1.0)
		speed = BallPhysics.launch_speed_for_carry(club.carry_yards * shot_power * lie, club.loft_deg)
	_ball.launch(dir, speed, club.loft_deg)
	shot_taken.emit(get_parent())
