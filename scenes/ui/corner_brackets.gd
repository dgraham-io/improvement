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
@export var breathe_period_sec: float = 3.4
@export var breathe_amount: float = 0.28

const FALLBACK_COLOR := Color(0.15, 0.75, 0.95, 0.85)

var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	if breathe_period_sec <= 0.0 or breathe_amount <= 0.0:
		return
	_t += delta / breathe_period_sec
	if _t >= 1.0:
		_t -= 1.0
	queue_redraw()


func _draw() -> void:
	var c := _resolve_color()
	if breathe_amount > 0.0:
		# Smooth sine breathing on alpha between (1 - amount) and 1.
		var phase := sin(_t * TAU)
		var factor := 1.0 - breathe_amount * 0.5 + (breathe_amount * 0.5) * phase
		c.a = clampf(c.a * factor, 0.0, 1.0)
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
