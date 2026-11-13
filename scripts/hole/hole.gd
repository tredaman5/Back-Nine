class_name Hole
extends Node3D
## Root of a hole prefab (hole_*.tscn): the tee, the cup and the out-of-bounds volume.
## MatchManager and the golfers ask the hole where things are instead of reaching into its children.

## Points the winner of this hole earns (holes 1-2 = 1, hole 3 = 2).
@export var points: int = 1
@export var hole_number: int = 1

@export_group("Green")
@export var green_radius: float = 14.0
## Constant downhill pull across the whole green (units/s^2, x and z).
@export var slope_base: Vector2 = Vector2(0.35, 0.1)
## Extra pull that swirls across the green so putts break differently in different spots.
## (Tuned by test: about 1 yd of break on a 10 yd putt.)
@export var slope_swirl: float = 0.3

## Radians per yard of the swirl.
const SWIRL_FREQUENCY: float = 0.35

@onready var tee: Marker3D = $Tee
@onready var green: Node3D = $Terrain/Green
@onready var cup: CupDetector = $Cup
@onready var oob: OOBDetector = $OutOfBounds


func tee_position() -> Vector3:
	return tee.global_position


func pin_position() -> Vector3:
	return cup.global_position


func green_center() -> Vector3:
	return green.global_position


## Downhill pull (units/s^2 along x and z) that a rolling ball feels at `pos`. Zero off the green.
## BallPhysics applies it and GreenReader draws it, so what you see is what the ball does.
func green_slope_at(pos: Vector3) -> Vector2:
	var center: Vector3 = green_center()
	var local := Vector2(pos.x - center.x, pos.z - center.z)
	if local.length() > green_radius:
		return Vector2.ZERO
	var swirl := Vector2(sin(local.y * SWIRL_FREQUENCY), cos(local.x * SWIRL_FREQUENCY))
	return slope_base + swirl * slope_swirl


## Flat (ground-plane) distance from `pos` to the pin, in yards.
func distance_to_pin(pos: Vector3) -> float:
	var pin: Vector3 = pin_position()
	return Vector2(pos.x - pin.x, pos.z - pin.z).length()
