class_name GreenReader
extends Node
## Green reading. Hold Shift on your turn to see a grid of arrows on the green that point downhill.
## Longer, redder arrows mean a stronger slope. A read costs one use the first time you hold Shift
## in a turn (you can look again for free that turn). You get MAX_READS per hole.

signal reads_changed(reads_left: int)

const MAX_READS: int = 3
const GRID_SPACING: float = 3.0
## Slope strength (units/s^2) drawn as the longest, reddest arrow.
const STRONG_SLOPE: float = 0.6
const GRID_HEIGHT: float = 0.12

@export var player_input_path: NodePath = ^"../PlayerInput"

var reads_left: int = MAX_READS
var showing: bool = false

var _input: PlayerInput
var _hole: Hole
var _grid: MeshInstance3D
var _active: bool = false
var _read_this_turn: bool = false


func _ready() -> void:
	_input = get_node(player_input_path) as PlayerInput
	_input.green_read_pressed.connect(_on_read_pressed)
	_input.green_read_released.connect(hide_grid)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grid = MeshInstance3D.new()
	_grid.top_level = true
	_grid.visible = false
	_grid.material_override = material
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)


## New hole: refill the reads and rebuild the grid for this green.
func start_hole(hole: Hole) -> void:
	_hole = hole
	reads_left = MAX_READS
	_read_this_turn = false
	hide_grid()
	_rebuild()
	reads_changed.emit(reads_left)


func begin_turn() -> void:
	_active = true
	_read_this_turn = false


func end_turn() -> void:
	_active = false
	hide_grid()


func hide_grid() -> void:
	showing = false
	_grid.visible = false


func _on_read_pressed() -> void:
	if not _active or _hole == null:
		return
	if not _read_this_turn:
		if reads_left <= 0:
			return
		reads_left -= 1
		_read_this_turn = true
		reads_changed.emit(reads_left)
	showing = true
	_grid.visible = true


func _rebuild() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector3 = _hole.green_center()
	var reach: float = _hole.green_radius - 1.0
	var steps: int = int(reach / GRID_SPACING)
	for ix: int in range(-steps, steps + 1):
		for iz: int in range(-steps, steps + 1):
			var offset := Vector2(ix, iz) * GRID_SPACING
			if offset.length() > reach:
				continue
			var spot := Vector2(center.x + offset.x, center.z + offset.y)
			var slope: Vector2 = _hole.green_slope_at(Vector3(spot.x, 0.0, spot.y))
			var strength: float = slope.length()
			if strength < 0.005:
				continue
			_add_arrow(st, spot, slope / strength, strength)
	_grid.mesh = st.commit()


func _add_arrow(st: SurfaceTool, at: Vector2, dir: Vector2, strength: float) -> void:
	var t: float = clampf(strength / STRONG_SLOPE, 0.0, 1.0)
	var length: float = lerpf(1.2, 2.6, t)
	var color: Color = Color(0.2, 0.6, 1.0, 0.9).lerp(Color(1.0, 0.25, 0.15, 0.9), t)
	var side := Vector2(-dir.y, dir.x)
	var tail: Vector2 = at - dir * length * 0.5
	var tip: Vector2 = at + dir * length * 0.5
	var neck: Vector2 = tip - dir * 0.9
	var shaft: float = 0.15
	var head: float = 0.45

	# Shaft (two triangles), then the arrow head (one triangle).
	_tri(st, color, tail + side * shaft, tail - side * shaft, neck + side * shaft)
	_tri(st, color, neck + side * shaft, tail - side * shaft, neck - side * shaft)
	_tri(st, color, neck + side * head, neck - side * head, tip)


func _tri(st: SurfaceTool, color: Color, a: Vector2, b: Vector2, c: Vector2) -> void:
	for p: Vector2 in [a, b, c]:
		st.set_color(color)
		st.add_vertex(Vector3(p.x, GRID_HEIGHT, p.y))
