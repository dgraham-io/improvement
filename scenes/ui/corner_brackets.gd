## L-shaped corner brackets drawn at the four corners of this Control's rect.
## Drop in as a child of a PanelContainer (or any Control) to frame content with
## a HUD-style overlay. Reads color from `CornerBrackets/colors/core` (theme).
class_name CornerBrackets
extends Control

@export var bracket_length: float = 14.0
@export var bracket_thickness: float = 2.0
@export var bracket_inset: float = 2.0
@export var color_key: StringName = &"core"
@export var theme_type: StringName = &"CornerBrackets"

const FALLBACK_COLOR := Color(0.97, 0.64, 0.1, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := _resolve_color()
	var s := size
	var i := bracket_inset
	var l := bracket_length
	var t := bracket_thickness
	# Top-left: horizontal arm + vertical arm
	draw_rect(Rect2(i, i, l, t), c, true)
	draw_rect(Rect2(i, i, t, l), c, true)
	# Top-right
	draw_rect(Rect2(s.x - i - l, i, l, t), c, true)
	draw_rect(Rect2(s.x - i - t, i, t, l), c, true)
	# Bottom-left
	draw_rect(Rect2(i, s.y - i - t, l, t), c, true)
	draw_rect(Rect2(i, s.y - i - l, t, l), c, true)
	# Bottom-right
	draw_rect(Rect2(s.x - i - l, s.y - i - t, l, t), c, true)
	draw_rect(Rect2(s.x - i - t, s.y - i - l, t, l), c, true)


func _resolve_color() -> Color:
	if has_theme_color(color_key, theme_type):
		return get_theme_color(color_key, theme_type)
	return FALLBACK_COLOR


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
