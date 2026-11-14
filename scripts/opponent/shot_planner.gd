class_name ShotPlanner
extends RefCounted
## Picks a club, power and aim for a shot. Used by OpponentAI, and by Bo's Caddie Call later,
## so the boss and the caddie "think" the same way. It plans a clean shot; the caller adds error.
##
## Putts account for the green's slope: the planner simulates the putt over the slope and
## aims at a point that makes the simulated ball finish in the cup.

## How much of the slope's pull a real rolling ball actually feels. The ball's own contact
## friction damps sideways rolling, so this is below 1. Fitted by test against the real ball
## (10 putts: error 0.5 yd at 0.8, versus 1.5 yd with no slope model).
const SLOPE_EFFECT: float = 0.8
const SIM_STEP: float = 0.05
const AIM_ITERATIONS: int = 8
## Never aim more than this many yards away from the pin to fight the slope.
const MAX_BREAK_AIM: float = 8.0


## Plan a shot for a ball at `ball_pos` lying on `surface`.
## `read_slope` is how much of the green's slope the planner "sees" (0 = none, 1 = all of it).
static func plan(ball_pos: Vector3, surface: StringName, hole: Hole, bag: Array[Club], read_slope: float = 1.0) -> ShotPlan:
	var result := ShotPlan.new()
	var pin: Vector3 = hole.pin_position()
	var to_pin := Vector2(pin.x - ball_pos.x, pin.z - ball_pos.z)
	var dist: float = to_pin.length()
	var straight: Vector3 = Vector3(to_pin.x, 0.0, to_pin.y).normalized() if dist > 0.01 else Vector3(0.0, 0.0, -1.0)
	result.aim_direction = straight

	if surface == &"green":
		result.club = _putter(bag)
		var putt: Dictionary = _solve_putt(ball_pos, hole, result.club, read_slope)
		result.aim_direction = putt["direction"]
		result.power = putt["power"]
		return result

	var lie: float = SwingController.LIE_POWER.get(surface, 1.0)
	result.club = _pick_flight_club(dist, lie, bag)
	result.power = clampf(dist / (result.club.carry_yards * lie), 0.1, 1.0)
	return result


## Where a putt hit from `start` toward `dir` for `roll` yards ends up, with the slope pulling it.
## `read_slope` scales the slope used. Mirrors the ball's roll model in BallPhysics.
static func simulate_putt(start: Vector2, dir: Vector2, roll: float, hole: Hole, read_slope: float) -> Vector2:
	var decel: float = BallPhysics.ROLL_DECEL[&"green"]
	var net: float = maxf(roll - BallPhysics.PUTT_ROLL_OFFSET, 0.1)
	# The speed the ball really rolls at once the engine's own friction has acted.
	var pos: Vector2 = start
	var vel: Vector2 = dir * sqrt(2.0 * decel * net)
	var t: float = 0.0
	while vel.length() > BallPhysics.STOP_SPEED and t < 20.0:
		var pull: Vector2 = hole.green_slope_at(Vector3(pos.x, 0.0, pos.y)) * SLOPE_EFFECT * read_slope
		vel += pull * SIM_STEP
		var speed: float = maxf(vel.length() - decel * SIM_STEP, 0.0)
		vel = vel.normalized() * speed if speed > 0.0 else Vector2.ZERO
		pos += vel * SIM_STEP
		t += SIM_STEP
	return pos + dir * BallPhysics.PUTT_ROLL_OFFSET


## Find the aim point and power so that the simulated putt finishes at the pin.
static func _solve_putt(ball_pos: Vector3, hole: Hole, putter: Club, read_slope: float) -> Dictionary:
	var pin3: Vector3 = hole.pin_position()
	var start := Vector2(ball_pos.x, ball_pos.z)
	var pin := Vector2(pin3.x, pin3.z)
	var aim_point: Vector2 = pin
	for i: int in AIM_ITERATIONS:
		var to_aim: Vector2 = aim_point - start
		var roll: float = minf(to_aim.length(), putter.putt_range_yards)
		if roll < 0.05:
			break
		var end: Vector2 = simulate_putt(start, to_aim.normalized(), roll, hole, read_slope)
		# Move the aim point by however far the putt missed.
		aim_point += pin - end
		if aim_point.distance_to(pin) > MAX_BREAK_AIM:
			aim_point = pin + (aim_point - pin).normalized() * MAX_BREAK_AIM
	var final: Vector2 = aim_point - start
	var dir2: Vector2 = final.normalized() if final.length() > 0.01 else (pin - start).normalized()
	return {
		"direction": Vector3(dir2.x, 0.0, dir2.y),
		"power": clampf(final.length() / putter.putt_range_yards, 0.05, 1.0),
	}


## The shortest flight club that reaches the pin from this lie, or the longest club if none does.
static func _pick_flight_club(dist: float, lie: float, bag: Array[Club]) -> Club:
	var longest: Club = null
	for i: int in range(bag.size() - 1, -1, -1):
		var c: Club = bag[i]
		if c.is_putter:
			continue
		if c.carry_yards * lie >= dist:
			return c
		longest = c
	return longest


static func _putter(bag: Array[Club]) -> Club:
	for c: Club in bag:
		if c.is_putter:
			return c
	return bag[0]
