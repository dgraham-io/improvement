## Filled diagonal accent triangles drawn at the four corners of this Control's
## rect. A static "corner-cut" sci-fi cue — no animation, fires only when the
## host panel becomes visible. Reads color from `CornerBrackets/colors/core`.
class_name CornerBrackets
extends Control

@export var accent_size: float = 8.0
@export var accent_inset: float = 2.0
@export var color_key: StringName = &"core"
@export var theme_type: StringName = &"CornerBrackets"

const FALLBACK_COLOR := Color(0.15, 0.75, 0.95, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := _resolve_color()
	var s := size
	var i := accent_inset
	var n := accent_size
	var ax := s.x - i
	var ay := s.y - i

	# Top-left triangle (right-angle at corner, hypotenuse facing inward)
	draw_colored_polygon(PackedVector2Array([
		Vector2(i, i),
		Vector2(i + n, i),
		Vector2(i, i + n),
	]), c)
	# Top-right
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax, i),
		Vector2(ax - n, i),
		Vector2(ax, i + n),
	]), c)
	# Bottom-left
	draw_colored_polygon(PackedVector2Array([
		Vector2(i, ay),
		Vector2(i + n, ay),
		Vector2(i, ay - n),
	]), c)
	# Bottom-right
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax, ay),
		Vector2(ax - n, ay),
		Vector2(ax, ay - n),
	]), c)


func _resolve_color() -> Color:
	if has_theme_color(color_key, theme_type):
		return get_theme_color(color_key, theme_type)
	return FALLBACK_COLOR


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
