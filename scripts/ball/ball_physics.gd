class_name BallPhysics
extends RigidBody3D
## Golf ball physics. 1 unit = 1 yard.
## Adds quadratic air drag, spin (Magnus) curve, surface-based landing damping and roll-out
## that comes to a clean stop. Launch with launch().

signal ball_landed(surface: StringName)
signal ball_stopped

## Air drag: acceleration = -DRAG_COEFF * |v| * v
const DRAG_COEFF: float = 0.0008
## Magnus curve: acceleration = MAGNUS_COEFF * spin x v
const MAGNUS_COEFF: float = 0.0001
## Fraction of spin lost per second.
const SPIN_DECAY: float = 0.15
## Horizontal speed below which a grounded ball stops (units/s).
const STOP_SPEED: float = 0.4
## Time after launch during which ground contact is ignored (stale contacts from the tee).
const LAUNCH_GRACE: float = 0.15

## Roll deceleration on each surface (units/s^2).
const ROLL_DECEL: Dictionary[StringName, float] = {
	&"green": 2.0,
	&"fairway": 4.0,
	&"rough": 14.0,
	&"sand": 40.0,
}
## Fraction of horizontal speed kept on each ground impact.
const LANDING_KEEP: Dictionary[StringName, float] = {
	&"green": 0.85,
	&"fairway": 0.75,
	&"rough": 0.45,
	&"sand": 0.1,
}

var spin: Vector3 = Vector3.ZERO
var in_flight: bool = false
var launch_position: Vector3 = Vector3.ZERO
var landing_position: Vector3 = Vector3.ZERO

var _airborne: bool = false
var _landing_reported: bool = false
var _grace: float = 0.0
var _pending_teleport: bool = false
var _teleport_position: Vector3 = Vector3.ZERO

@onready var _surface_detector: SurfaceDetector = $SurfaceDetector


## Launch the ball. `direction` is the horizontal aim; `sidespin` > 0 draws left, < 0 fades right;
## `backspin` > 0 adds lift.
func launch(direction: Vector3, speed: float, loft_deg: float, sidespin: float = 0.0, backspin: float = 0.0) -> void:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	var loft: float = deg_to_rad(loft_deg)
	sleeping = false
	launch_position = global_position
	linear_velocity = (flat * cos(loft) + Vector3.UP * sin(loft)) * speed
	spin = Vector3.UP * sidespin + flat.cross(Vector3.UP) * backspin
	angular_velocity = Vector3.ZERO
	in_flight = true
	_airborne = false
	_landing_reported = false
	_grace = LAUNCH_GRACE


## Teleport the ball to a position and stop it (safe to call any time).
func teleport(pos: Vector3) -> void:
	_teleport_position = pos
	_pending_teleport = true
	sleeping = false


## Surface name under the ball right now (&"air" if none).
func current_surface() -> StringName:
	return _surface_detector.get_surface()


## Horizontal distance from launch to the first landing.
func carry_distance() -> float:
	return Vector2(landing_position.x - launch_position.x, landing_position.z - launch_position.z).length()


## Horizontal distance from launch to where the ball is now.
func total_distance() -> float:
	return Vector2(global_position.x - launch_position.x, global_position.z - launch_position.z).length()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		state.transform = Transform3D(Basis.IDENTITY, _teleport_position)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		spin = Vector3.ZERO
		in_flight = false
		_airborne = false
		_pending_teleport = false
		return

	var dt: float = state.step
	var v: Vector3 = state.linear_velocity
	_grace = maxf(_grace - dt, 0.0)
	var on_ground: bool = _grace <= 0.0 and state.get_contact_count() > 0

	if not on_ground:
		var speed: float = v.length()
		v += (-DRAG_COEFF * speed * v + MAGNUS_COEFF * spin.cross(v)) * dt
		spin *= maxf(1.0 - SPIN_DECAY * dt, 0.0)
		state.linear_velocity = v
		if in_flight:
			_airborne = true
		return

	var surface: StringName = _surface_detector.get_surface()
	if surface == SurfaceDetector.AIR:
		surface = SurfaceDetector.DEFAULT_SURFACE

	if _airborne:
		# Just touched down: damp by surface.
		_airborne = false
		var keep: float = LANDING_KEEP.get(surface, 0.45)
		v.x *= keep
		v.z *= keep
		spin *= 0.3
		if not _landing_reported:
			_landing_reported = true
			landing_position = state.transform.origin
			ball_landed.emit.call_deferred(surface)

	var horizontal := Vector3(v.x, 0.0, v.z)
	var h_speed: float = horizontal.length()
	if h_speed < STOP_SPEED and absf(v.y) < 1.0:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		spin = Vector3.ZERO
		if in_flight:
			in_flight = false
			ball_stopped.emit.call_deferred()
		return

	var decel: float = ROLL_DECEL.get(surface, 14.0)
	var new_h: float = maxf(h_speed - decel * dt, 0.0)
	if h_speed > 0.0:
		horizontal *= new_h / h_speed
	state.linear_velocity = Vector3(horizontal.x, v.y, horizontal.z)


## Launch speed (units/s) that produces `carry` yards of flight on flat ground at `loft_deg`,
## using the same gravity and air drag as the live ball (no spin, no wind).
static func launch_speed_for_carry(carry: float, loft_deg: float) -> float:
	var lo: float = 1.0
	var hi: float = 300.0
	for i: int in 28:
		var mid: float = (lo + hi) * 0.5
		if _simulate_carry(mid, loft_deg) < carry:
			lo = mid
		else:
			hi = mid
	return hi


static func _simulate_carry(speed: float, loft_deg: float) -> float:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var dt: float = 1.0 / 240.0
	var loft: float = deg_to_rad(loft_deg)
	var pos := Vector2.ZERO
	var vel := Vector2(cos(loft), sin(loft)) * speed
	for i: int in 6000:
		var s: float = vel.length()
		vel += (-DRAG_COEFF * s * vel + Vector2(0.0, -g)) * dt
		pos += vel * dt
		if pos.y <= 0.0:
			break
	return pos.x
