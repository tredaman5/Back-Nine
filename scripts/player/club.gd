class_name Club
extends Resource
## One club's data. Distances are in yards (1 unit = 1 yard).

@export var display_name: String = ""
## Carry distance at 100% power (flight clubs). Unused by the putter.
@export var carry_yards: float = 0.0
@export var loft_deg: float = 0.0
@export var is_putter: bool = false
## Putter only: roll distance at 100% power.
@export var putt_range_yards: float = 30.0


## How far the aim line extends: carry for flight clubs, roll distance for the putter.
func range_yards() -> float:
	return putt_range_yards if is_putter else carry_yards


static func make(p_name: String, p_carry: float, p_loft: float, p_putter: bool = false) -> Club:
	var c := Club.new()
	c.display_name = p_name
	c.carry_yards = p_carry
	c.loft_deg = p_loft
	c.is_putter = p_putter
	return c
