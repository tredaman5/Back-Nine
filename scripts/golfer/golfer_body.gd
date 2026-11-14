class_name GolferBody
extends Node3D
## A blocky golfer built from primitive shapes, with an AnimationPlayer made in code.
## Placeholder art: real models replace the meshes later, and the animation names stay the same.
## The body faces -Z and swings its club along local X (Golfer turns it to match the aim).
##
## Animations: idle, backswing, swing, putt_back, putt, celebrate, disappointed, taunt.

@export var shirt_color: Color = Color(0.2, 0.4, 0.95)
@export var pants_color: Color = Color(0.18, 0.2, 0.28)
@export var skin_color: Color = Color(0.9, 0.7, 0.55)

## Height of the hips (yards); the torso pivots here.
const HIP_HEIGHT: float = 0.85

var _player: AnimationPlayer
var _torso: Node3D


func _ready() -> void:
	_build_body()
	_build_animations()
	play_anim(&"idle")


## Play an animation by name (idle, backswing, swing, putt_back, putt, celebrate, disappointed, taunt).
func play_anim(anim: StringName) -> void:
	if _player != null and _player.has_animation(anim):
		_player.play(anim)


## Raise the club to the top of the swing (or draw the putter back). Holds that pose.
func play_backswing(putting: bool) -> void:
	play_anim(&"putt_back" if putting else &"backswing")


## Swing through the ball. Holds the finish pose.
func play_swing(putting: bool) -> void:
	play_anim(&"putt" if putting else &"swing")


func _build_body() -> void:
	# Legs.
	_box(self, Vector3(0.2, 0.85, 0.22), Vector3(-0.14, 0.425, 0.0), pants_color)
	_box(self, Vector3(0.2, 0.85, 0.22), Vector3(0.14, 0.425, 0.0), pants_color)

	# Torso pivots at the hips so it can lean and twist; the head and arms ride on it.
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0.0, HIP_HEIGHT, 0.0)
	add_child(_torso)
	_box(_torso, Vector3(0.52, 0.62, 0.3), Vector3(0.0, 0.31, 0.0), shirt_color)
	_sphere(_torso, 0.17, Vector3(0.0, 0.78, 0.0), skin_color)
	# A cap so you can tell which way the head faces.
	_box(_torso, Vector3(0.3, 0.07, 0.34), Vector3(0.0, 0.92, -0.04), shirt_color.darkened(0.3))

	# Shoulders: both arms and the club swing together from here.
	var arms := Node3D.new()
	arms.name = "Arms"
	arms.position = Vector3(0.0, 0.56, 0.0)
	_torso.add_child(arms)
	_box(arms, Vector3(0.11, 0.6, 0.11), Vector3(-0.18, -0.3, 0.0), skin_color)
	_box(arms, Vector3(0.11, 0.6, 0.11), Vector3(0.18, -0.3, 0.0), skin_color)
	var club := Node3D.new()
	club.name = "Club"
	club.position = Vector3(0.0, -0.6, 0.0)
	arms.add_child(club)
	_box(club, Vector3(0.03, 1.0, 0.03), Vector3(0.0, -0.5, 0.0), Color(0.75, 0.75, 0.78))
	_box(club, Vector3(0.12, 0.06, 0.2), Vector3(0.0, -1.0, 0.06), Color(0.25, 0.25, 0.28))


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_mesh(parent, mesh, pos, color)


func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_add_mesh(parent, mesh, pos, color)


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)


# ---- Animations (poses are rows: time, torso lean, torso twist, arms pitch, arms swing, hip height) ----

func _build_animations() -> void:
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)

	var base: Array = [-0.25, 0.0, 0.5, 0.0, HIP_HEIGHT]
	var library := AnimationLibrary.new()

	library.add_animation(&"idle", _pose_animation(3.0, true, [
		[0.0] + base,
		[1.5, -0.25, 0.04, 0.5, 0.02, HIP_HEIGHT],
		[3.0] + base,
	]))
	library.add_animation(&"backswing", _pose_animation(0.55, false, [
		[0.0] + base,
		[0.55, -0.2, 0.7, 0.2, -1.7, HIP_HEIGHT],
	]))
	library.add_animation(&"swing", _pose_animation(1.4, false, [
		[0.0, -0.2, 0.7, 0.2, -1.7, HIP_HEIGHT],
		[0.12, -0.25, -0.1, 0.5, 0.0, HIP_HEIGHT],
		[0.45, -0.1, -0.8, 0.1, 1.9, HIP_HEIGHT],
		[1.4, -0.1, -0.8, 0.1, 1.9, HIP_HEIGHT],
	]))
	library.add_animation(&"putt_back", _pose_animation(0.35, false, [
		[0.0, -0.45, 0.0, 0.55, 0.0, HIP_HEIGHT],
		[0.35, -0.45, 0.0, 0.55, -0.3, HIP_HEIGHT],
	]))
	library.add_animation(&"putt", _pose_animation(1.0, false, [
		[0.0, -0.45, 0.0, 0.55, -0.3, HIP_HEIGHT],
		[0.1, -0.45, 0.0, 0.55, 0.0, HIP_HEIGHT],
		[0.5, -0.45, 0.0, 0.55, 0.3, HIP_HEIGHT],
		[1.0, -0.45, 0.0, 0.55, 0.3, HIP_HEIGHT],
	]))
	library.add_animation(&"celebrate", _pose_animation(2.0, false, [
		[0.0] + base,
		[0.3, 0.0, 0.0, -2.9, 0.0, HIP_HEIGHT + 0.12],
		[0.6, 0.0, 0.0, -2.9, 0.0, HIP_HEIGHT],
		[0.9, 0.0, 0.0, -2.9, 0.0, HIP_HEIGHT + 0.12],
		[1.2, 0.0, 0.0, -2.9, 0.0, HIP_HEIGHT],
		[2.0, 0.0, 0.0, -2.9, 0.0, HIP_HEIGHT],
	]))
	library.add_animation(&"disappointed", _pose_animation(2.0, false, [
		[0.0] + base,
		[0.6, -0.6, 0.0, 0.15, 0.0, HIP_HEIGHT - 0.03],
		[2.0, -0.6, 0.0, 0.15, 0.0, HIP_HEIGHT - 0.03],
	]))
	library.add_animation(&"taunt", _pose_animation(1.6, false, [
		[0.0] + base,
		[0.3, 0.0, 0.3, -1.3, 0.3, HIP_HEIGHT],
		[0.6, 0.0, -0.3, -1.3, -0.3, HIP_HEIGHT],
		[0.9, 0.0, 0.3, -1.3, 0.3, HIP_HEIGHT],
		[1.2, 0.0, -0.3, -1.3, -0.3, HIP_HEIGHT],
		[1.6] + base,
	]))
	_player.add_animation_library(&"", library)


## Build one animation from pose rows. Every pose key sets all five values, so no animation
## leaves a leftover pose behind from the one before.
func _pose_animation(length: float, loop: bool, rows: Array) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var paths: Array[String] = [
		"Torso:rotation:x", "Torso:rotation:y", "Torso/Arms:rotation:x", "Torso/Arms:rotation:z", "Torso:position:y",
	]
	for i: int in paths.size():
		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath(paths[i]))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for row: Array in rows:
			anim.track_insert_key(track, row[0], row[i + 1])
	return anim
