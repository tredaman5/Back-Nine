class_name Opponent
extends Golfer
## A boss golfer. OpponentAI plans and takes the shots. Boss rules (BossRule) arrive in a later step.

@onready var _ai: OpponentAI = $OpponentAI


func _ready() -> void:
	_ai.shot_taken.connect(_on_ai_shot_taken)


func set_ball(new_ball: BallPhysics) -> void:
	super(new_ball)
	_ai.set_ball(new_ball)


func aim_direction() -> Vector3:
	return _ai.aim_direction


func is_putting() -> bool:
	return _ai.is_putting()


func begin_turn() -> void:
	_ai.take_turn(hole)


func _on_ai_shot_taken(_node: Node) -> void:
	shot_taken.emit(self)
