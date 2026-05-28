## Slow horizontal sweep bar that animates top-to-bottom over a fixed period.
## Layered over the whole viewport. Reads colors from
## `HudScanBar/colors/{line,bloom}` (theme).
class_name HudScanBar
extends Control

@export var sweep_period_sec: float = 9.0
@export var bar_thickness: float = 1.0
@export var bloom_thickness: float = 36.0

const FALLBACK_LINE := Color(0.15, 0.75, 0.95, 0.55)
const FALLBACK_BLOOM := Color(0.15, 0.75, 0.95, 0.08)

var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if sweep_period_sec <= 0.0:
		return
	_t += delta / sweep_period_sec
	if _t >= 1.0:
		_t -= 1.0
	queue_redraw()


func _draw() -> void:
	if size.y <= 0.0:
		return
	var line_c := _color(&"line", FALLBACK_LINE)
	var bloom_c := _color(&"bloom", FALLBACK_BLOOM)
	var y := _t * size.y
	# Soft bloom band
	draw_rect(
		Rect2(0.0, y - bloom_thickness * 0.5, size.x, bloom_thickness),
		bloom_c,
		true
	)
	# Sharp scan line
	draw_rect(
		Rect2(0.0, y - bar_thickness * 0.5, size.x, bar_thickness),
		line_c,
		true
	)


func _color(key: StringName, fallback: Color) -> Color:
	if has_theme_color(key, &"HudScanBar"):
		return get_theme_color(key, &"HudScanBar")
	return fallback


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
