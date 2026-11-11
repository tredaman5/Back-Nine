class_name Hole
extends Node3D
## Root of a hole prefab (hole_*.tscn): the tee, the cup and the out-of-bounds volume.
## MatchManager and the golfers ask the hole where things are instead of reaching into its children.

## Points the winner of this hole earns (holes 1-2 = 1, hole 3 = 2).
@export var points: int = 1
@export var hole_number: int = 1

@onready var tee: Marker3D = $Tee
@onready var cup: CupDetector = $Cup
@onready var oob: OOBDetector = $OutOfBounds


func tee_position() -> Vector3:
	return tee.global_position


func pin_position() -> Vector3:
	return cup.global_position


## Flat (ground-plane) distance from `pos` to the pin, in yards.
func distance_to_pin(pos: Vector3) -> float:
	var pin: Vector3 = pin_position()
	return Vector2(pos.x - pin.x, pos.z - pin.z).length()
