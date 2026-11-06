class_name PlayerInput
extends Node
## Reads mouse, keyboard and controller input through Input Map actions and re-emits it as signals.
## Also holds the current club and shot shape selection.

signal club_changed(club: Club)
signal shape_changed(shape: StringName)
## Mouse horizontal position as -1 (left edge) .. 1 (right edge). Not sent while swinging.
signal mouse_aimed(norm_x: float)
signal swing_pressed
signal swing_released
signal green_read_pressed
signal clutch_pressed
signal caddie_call_pressed
signal pause_pressed

const SHAPES: Array[StringName] = [&"straight", &"draw", &"fade", &"high_lob"]

## Set false to ignore all input (opponent's turn, shot in flight, menus).
var enabled: bool = true
var clubs: Array[Club] = []
var club_index: int = 0
var shape_index: int = 0
## High Lob unlocks after Match01. (Stinger after Match02 is added with the unlock step.)
var unlocked_shapes: Dictionary[StringName, bool] = {
	&"straight": true,
	&"draw": true,
	&"fade": true,
	&"high_lob": false,
}


func _ready() -> void:
	clubs = [
		Club.make("Driver", 250.0, 12.0),
		Club.make("7 Iron", 160.0, 28.0),
		Club.make("Wedge", 90.0, 48.0),
		Club.make("Putter", 0.0, 0.0, true),
	]


func current_club() -> Club:
	return clubs[club_index]


func current_shape() -> StringName:
	return SHAPES[shape_index]


## Aim turn input: +1 = turn left, -1 = turn right (keyboard arrows or left stick).
func get_aim_axis() -> float:
	return Input.get_axis("aim_right", "aim_left")


func is_swing_held() -> bool:
	return Input.is_action_pressed("swing")


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		if not is_swing_held():
			var half: float = get_viewport().get_visible_rect().size.x * 0.5
			mouse_aimed.emit(clampf((motion.position.x - half) / half, -1.0, 1.0))
		return

	if event.is_action_pressed("club_prev"):
		_step_club(-1)
	elif event.is_action_pressed("club_next"):
		_step_club(1)
	elif event.is_action_pressed("shape_1"):
		_select_shape(0)
	elif event.is_action_pressed("shape_2"):
		_select_shape(1)
	elif event.is_action_pressed("shape_3"):
		_select_shape(2)
	elif event.is_action_pressed("shape_4"):
		_select_shape(3)
	elif event.is_action_pressed("shape_prev"):
		_step_shape(-1)
	elif event.is_action_pressed("shape_next"):
		_step_shape(1)
	elif event.is_action_pressed("swing"):
		swing_pressed.emit()
	elif event.is_action_released("swing"):
		swing_released.emit()
	elif event.is_action_pressed("green_read"):
		green_read_pressed.emit()
	elif event.is_action_pressed("clutch_shot"):
		clutch_pressed.emit()
	elif event.is_action_pressed("caddie_call"):
		caddie_call_pressed.emit()
	elif event.is_action_pressed("pause"):
		pause_pressed.emit()


func _step_club(step: int) -> void:
	club_index = posmod(club_index + step, clubs.size())
	club_changed.emit(clubs[club_index])


func _select_shape(index: int) -> void:
	if not unlocked_shapes.get(SHAPES[index], false):
		return
	shape_index = index
	shape_changed.emit(SHAPES[index])


func _step_shape(step: int) -> void:
	var i: int = shape_index
	for n: int in SHAPES.size():
		i = posmod(i + step, SHAPES.size())
		if unlocked_shapes.get(SHAPES[i], false):
			_select_shape(i)
			return
