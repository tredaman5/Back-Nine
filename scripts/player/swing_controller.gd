class_name SwingController
extends Node
## Two-stage swing meter.
## Stage 1 (POWER): hold swing and drag the mouse down (or pull the left stick down) to set power 0-100%.
## Release to lock power.
## Stage 2 (ACCURACY): a marker sweeps across the bar. Press swing again to stop it.
## Inside the green window = a clean shot. Outside = hook (early) or slice (late).
## Launches the ball with the club's distance scaled by power and lie.

enum State { IDLE, POWER, ACCURACY, LAUNCHED }

signal state_changed(new_state: State)
## power 0-1, error -1..1 (negative = early/hook, positive = late/slice), in_window, centered.
signal swing_resolved(result: Dictionary)
signal shot_taken(golfer: Node)

const DRAW_SIDESPIN: float = 250.0
const HIGH_LOB_EXTRA_LOFT: float = 15.0
## Power multiplier by lie (rough -20%, sand -40%).
const LIE_POWER: Dictionary[StringName, float] = {
	&"rough": 0.8,
	&"sand": 0.6,
}

@export var player_input_path: NodePath = ^"../PlayerInput"
@export var shot_aim_path: NodePath = ^"../ShotAim"
## Mouse travel (pixels) for 100% power.
@export var drag_pixels_full: float = 250.0
## Seconds for the accuracy marker to cross the bar.
@export var sweep_time: float = 1.1
@export var window_center: float = 0.5
## Half-width of the green window as a fraction of the bar, at normal Pressure.
@export var base_half_width: float = 0.10
@export var miss_sidespin: float = 350.0
## Putter: degrees of direction error at the worst miss.
@export var miss_putt_yaw_deg: float = 6.0
@export var pressure_threshold: float = 70.0
## The window shrinks by this fraction above the threshold.
@export var pressure_shrink: float = 0.4

var state: State = State.IDLE
var power: float = 0.0
var marker: float = 0.0
## Multiplier on the window width. The Clutch Shot sets this wide.
var window_scale: float = 1.0
var pressure: float = 0.0

var _input: PlayerInput
var _aim: ShotAim
var _ball: BallPhysics
var _press_y: float = 0.0


func _ready() -> void:
	_input = get_node(player_input_path) as PlayerInput
	_aim = get_node(shot_aim_path) as ShotAim
	_input.swing_pressed.connect(_on_swing_pressed)
	_input.swing_released.connect(_on_swing_released)


func set_ball(ball: BallPhysics) -> void:
	_ball = ball
	_ball.ball_stopped.connect(reset)


func set_pressure(value: float) -> void:
	pressure = value


## Current half-width of the green window (fraction of the bar).
func window_half_width() -> float:
	var half: float = base_half_width * window_scale
	if pressure > pressure_threshold:
		half *= 1.0 - pressure_shrink
	return half


## Back to idle and ready for the next shot. Whether input is live is up to the turn order (Player).
func reset() -> void:
	power = 0.0
	marker = 0.0
	_set_state(State.IDLE)


func _process(delta: float) -> void:
	match state:
		State.POWER:
			var mouse_power: float = (get_viewport().get_mouse_position().y - _press_y) / drag_pixels_full
			var stick: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
			var stick_power: float = stick if stick > 0.2 else 0.0
			power = clampf(maxf(mouse_power, stick_power), 0.0, 1.0)
		State.ACCURACY:
			marker += delta / sweep_time
			if marker >= 1.0:
				marker = 1.0
				_fire()


func _on_swing_pressed() -> void:
	if _ball == null or _ball.in_flight:
		return
	match state:
		State.IDLE:
			_press_y = get_viewport().get_mouse_position().y
			power = 0.0
			_set_state(State.POWER)
		State.ACCURACY:
			_fire()


func _on_swing_released() -> void:
	if state != State.POWER:
		return
	if power < 0.05:
		# Dragged back to the start: cancel.
		power = 0.0
		_set_state(State.IDLE)
		return
	marker = 0.0
	_set_state(State.ACCURACY)


## Resolve the accuracy marker and launch the ball.
func _fire() -> void:
	var dev: float = marker - window_center
	var half: float = window_half_width()
	var in_window: bool = absf(dev) <= half
	var centered: bool = absf(dev) <= half * 0.35
	var miss: float = 0.0
	if not in_window:
		miss = clampf((absf(dev) - half) / (0.5 - half), 0.0, 1.0)
	# Negative = early (hook), positive = late (slice).
	var error: float = signf(dev) * miss

	var club: Club = _input.current_club()
	var shape: StringName = _input.current_shape()
	var surface: StringName = _ball.current_surface()
	var eff_power: float = power * LIE_POWER.get(surface, 1.0)
	var dir: Vector3 = _aim.get_direction()
	var loft: float = club.loft_deg
	var speed: float
	var sidespin: float = 0.0

	if club.is_putter:
		# Direction error instead of spin. Late = right.
		dir = dir.rotated(Vector3.UP, deg_to_rad(-error * miss_putt_yaw_deg))
		speed = BallPhysics.launch_speed_for_putt(club.putt_range_yards * eff_power, surface)
	else:
		match shape:
			&"draw":
				sidespin = DRAW_SIDESPIN
			&"fade":
				sidespin = -DRAW_SIDESPIN
			&"high_lob":
				loft += HIGH_LOB_EXTRA_LOFT
		# A hook (early) curves left, a slice (late) curves right, on top of the shape.
		sidespin -= error * miss_sidespin
		speed = BallPhysics.launch_speed_for_carry(club.carry_yards * eff_power, loft)

	swing_resolved.emit({
		"power": power,
		"error": error,
		"in_window": in_window,
		"centered": centered,
	})
	_input.enabled = false
	_set_state(State.LAUNCHED)
	_ball.launch(dir, speed, loft, sidespin)
	shot_taken.emit(get_parent())


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
