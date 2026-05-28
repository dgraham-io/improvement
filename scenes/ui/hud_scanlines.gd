## Faint horizontal scanlines drawn over the entire viewport (CRT/HUD overlay).
## Reads `HudScanlines/colors/line` from theme.
class_name HudScanlines
extends Control

@export var line_spacing: float = 3.0

const FALLBACK_LINE := Color(0, 0, 0, 0.10)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := _color()
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), c, 1.0, false)
		y += line_spacing


func _color() -> Color:
	if has_theme_color(&"line", &"HudScanlines"):
		return get_theme_color(&"line", &"HudScanlines")
	return FALLBACK_LINE


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
