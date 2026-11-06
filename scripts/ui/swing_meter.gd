class_name SwingMeter
extends Control
## Draws the power bar and the accuracy bar for a SwingController.
## Hidden while the swing is idle. Will live inside the HUD later.

const BAR_SIZE: Vector2 = Vector2(440.0, 90.0)
const POWER_BAR: Rect2 = Rect2(0.0, 0.0, 440.0, 26.0)
const ACCURACY_BAR: Rect2 = Rect2(0.0, 44.0, 440.0, 30.0)

var swing: SwingController


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Never eat swing clicks.
	size = BAR_SIZE


func bind(controller: SwingController) -> void:
	swing = controller


func _process(_delta: float) -> void:
	if swing == null:
		return
	visible = swing.state == SwingController.State.POWER or swing.state == SwingController.State.ACCURACY
	var vp: Vector2 = get_viewport_rect().size
	position = Vector2((vp.x - BAR_SIZE.x) * 0.5, vp.y - BAR_SIZE.y - 40.0)
	queue_redraw()


func _draw() -> void:
	if swing == null:
		return
	# Power bar.
	draw_rect(POWER_BAR, Color(0, 0, 0, 0.6))
	var fill := Rect2(POWER_BAR.position, Vector2(POWER_BAR.size.x * swing.power, POWER_BAR.size.y))
	draw_rect(fill, Color(0.95, 0.75, 0.2).lerp(Color(0.95, 0.25, 0.2), swing.power))
	draw_rect(POWER_BAR, Color.WHITE, false, 2.0)

	# Accuracy bar (only meaningful in stage 2).
	var bar: Rect2 = ACCURACY_BAR
	draw_rect(bar, Color(0.55, 0.12, 0.12, 0.85))
	var half: float = swing.window_half_width()
	var win := Rect2(
		bar.position.x + bar.size.x * (swing.window_center - half),
		bar.position.y,
		bar.size.x * half * 2.0,
		bar.size.y)
	draw_rect(win, Color(0.2, 0.85, 0.3, 0.95))
	draw_rect(bar, Color.WHITE, false, 2.0)
	if swing.state == SwingController.State.ACCURACY:
		var x: float = bar.position.x + bar.size.x * swing.marker
		draw_rect(Rect2(x - 3.0, bar.position.y - 6.0, 6.0, bar.size.y + 12.0), Color.WHITE)
