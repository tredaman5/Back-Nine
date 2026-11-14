class_name OpponentAI
extends Node
## Takes the boss's shots. ShotPlanner decides the clean shot (club, power, aim, and the break of a
## putt); this class adds random error set by the boss's skill and then swings.

signal shot_taken(golfer: Node)
## The boss raises the club, a moment before the swing.
signal backswing_started

## Seconds the boss "thinks" before swinging, so the camera can show the setup.
@export var think_time: float = 1.2
## 0 = sloppy, 1 = nearly perfect. Sets the random aim and power error.
@export_range(0.0, 1.0) var skill: float = 0.5
## How much of the green's slope the boss reads: 0 = ignores it, 1 = reads it fully.
@export_range(0.0, 1.0) var green_reading: float = 0.5

## Aim error on full shots, standard deviation in degrees, for the worst and best skill.
const AIM_ERROR_WORST: float = 5.0
const AIM_ERROR_BEST: float = 0.5
## Power error (fraction of full power), standard deviation, for the worst and best skill.
const POWER_ERROR_WORST: float = 0.08
const POWER_ERROR_BEST: float = 0.01
## Putts use this fraction of the full-shot aim error.
const PUTT_AIM_FACTOR: float = 0.25

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
	var plan: ShotPlan = ShotPlanner.plan(_ball.global_position, _ball.current_surface(), _hole, _bag, green_reading)
	club = plan.club
	power = plan.power
	aim_direction = plan.aim_direction
	await get_tree().create_timer(think_time * 0.6).timeout
	if token != _token:
		return
	backswing_started.emit()
	await get_tree().create_timer(think_time * 0.4).timeout
	if token != _token:
		return
	_execute()


func _execute() -> void:
	var aim_error: float = lerpf(AIM_ERROR_WORST, AIM_ERROR_BEST, skill) * (PUTT_AIM_FACTOR if club.is_putter else 1.0)
	var yaw_error: float = randfn(0.0, aim_error)
	var dir: Vector3 = aim_direction.rotated(Vector3.UP, deg_to_rad(yaw_error))
	var power_error: float = lerpf(POWER_ERROR_WORST, POWER_ERROR_BEST, skill)
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
