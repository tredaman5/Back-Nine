class_name Player
extends Golfer
## Dez. Wires PlayerInput, ShotAim and SwingController into the match: input is only live on Dez's turn.

@onready var _input: PlayerInput = $PlayerInput
@onready var _aim: ShotAim = $ShotAim
@onready var _swing: SwingController = $SwingController
@onready var _reader: GreenReader = $GreenReader


func _ready() -> void:
	_swing.shot_taken.connect(_on_swing_shot_taken)
	_input.club_changed.connect(_on_club_changed)
	_swing.state_changed.connect(_on_swing_state_changed)


func set_ball(new_ball: BallPhysics) -> void:
	super(new_ball)
	_aim.set_ball(new_ball)
	_swing.set_ball(new_ball)


func bind_match(manager: MatchManager) -> void:
	super(manager)
	manager.hole_started.connect(_reader.start_hole)


func aim_direction() -> Vector3:
	return _aim.get_direction()


func is_putting() -> bool:
	return _input.current_club().is_putter


func begin_turn() -> void:
	_swing.reset()
	_input.enabled = true
	_aim.aim_at(hole.pin_position())
	_reader.begin_turn()


func end_turn() -> void:
	_input.enabled = false
	_reader.end_turn()


func _on_swing_shot_taken(_node: Node) -> void:
	_reader.hide_grid()
	show_swing()
	shot_taken.emit(self)


# Raise the club while the accuracy marker is sweeping; drop it if the swing is cancelled.
func _on_swing_state_changed(state: SwingController.State) -> void:
	if state == SwingController.State.ACCURACY:
		show_backswing()
	elif state == SwingController.State.IDLE and body != null:
		body.play_anim(&"idle")


func _on_club_changed(club: Club) -> void:
	putting_changed.emit(club.is_putter)
