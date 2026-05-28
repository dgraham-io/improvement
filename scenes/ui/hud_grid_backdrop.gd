## Engineering-blueprint grid drawn faintly behind the panels.
## Minor lines on a regular cell grid; brighter crosshair pips at every
## `major_every` intersection. Reads colors from `HudGrid/colors/{minor,major}`.
class_name HudGridBackdrop
extends Control

@export var cell_size: float = 32.0
@export var major_every: int = 4
@export var crosshair_arm: float = 4.0

const FALLBACK_MINOR := Color(0.97, 0.64, 0.1, 0.05)
const FALLBACK_MAJOR := Color(0.97, 0.64, 0.1, 0.18)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var minor := _color(&"minor", FALLBACK_MINOR)
	var major := _color(&"major", FALLBACK_MAJOR)
	var s := size

	var x := 0.0
	while x < s.x:
		draw_line(Vector2(x, 0.0), Vector2(x, s.y), minor, 1.0, false)
		x += cell_size
	var y := 0.0
	while y < s.y:
		draw_line(Vector2(0.0, y), Vector2(s.x, y), minor, 1.0, false)
		y += cell_size

	if major_every <= 0:
		return
	var step := cell_size * float(major_every)
	var mx := 0.0
	while mx < s.x:
		var my := 0.0
		while my < s.y:
			draw_line(Vector2(mx - crosshair_arm, my), Vector2(mx + crosshair_arm, my), major, 1.0, false)
			draw_line(Vector2(mx, my - crosshair_arm), Vector2(mx, my + crosshair_arm), major, 1.0, false)
			my += step
		mx += step


func _color(key: StringName, fallback: Color) -> Color:
	if has_theme_color(key, &"HudGrid"):
		return get_theme_color(key, &"HudGrid")
	return fallback


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
