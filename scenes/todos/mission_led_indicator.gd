## Vertical rounded-rect LED: lit while this mission has an active pomodoro.
class_name MissionLedIndicator
extends Control

const LED_SIZE := Vector2(12, 26)
const CORNER_RADIUS := 6
const GLOW_COLOR := Color(0.133333, 0.866667, 1, 1)
const CORE_COLOR := Color(0.55, 0.98, 1, 1)
const OFF_FILL := Color(0.06, 0.08, 0.14, 1)
const OFF_BORDER := Color(0.28, 0.32, 0.42, 0.55)

var _active := false


func _ready() -> void:
	custom_minimum_size = LED_SIZE + Vector2(8, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()


func _draw() -> void:
	if _active:
		_draw_lit_led(false)
	else:
		_draw_off_led()


func _led_rect(size_scale: Vector2 = Vector2.ONE) -> Rect2:
	var led_size := Vector2(LED_SIZE.x * size_scale.x, LED_SIZE.y * size_scale.y)
	return Rect2(size * 0.5 - led_size * 0.5, led_size)


func _draw_lit_led(hovered: bool) -> void:
	var glow := 1.1 if hovered else 1.0
	_draw_rounded_fill(_led_rect(Vector2(1.22 * glow, 1.2 * glow)), Color(GLOW_COLOR, 0.14))
	_draw_rounded_fill(_led_rect(Vector2(1.08 * glow, 1.08 * glow)), Color(GLOW_COLOR, 0.24))
	_draw_rounded_border(_led_rect(), GLOW_COLOR, 0.55, 1.25)
	_draw_rounded_fill(_led_rect(Vector2(0.76, 0.76)), CORE_COLOR)
	var core := _led_rect(Vector2(0.76, 0.76))
	var spec := Rect2(
		core.position + Vector2(core.size.x * 0.12, core.size.y * 0.1),
		Vector2(core.size.x * 0.45, core.size.y * 0.22)
	)
	_draw_rounded_fill(spec, Color(1, 1, 1, 0.38), CORNER_RADIUS / 2)


func _draw_off_led() -> void:
	_draw_rounded_fill(_led_rect(), OFF_FILL)
	_draw_rounded_border(_led_rect(), OFF_BORDER, 1.0, 1.0)
	var inner := _led_rect(Vector2(0.7, 0.55))
	inner.position.y += LED_SIZE.y * 0.08
	_draw_rounded_fill(inner, Color(0, 0, 0, 0.2), CORNER_RADIUS - 2)


func _draw_rounded_fill(rect: Rect2, color: Color, radius: int = CORNER_RADIUS) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.draw(get_canvas_item(), rect)


func _draw_rounded_border(rect: Rect2, color: Color, alpha: float, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(color, alpha)
	style.set_border_width_all(int(maxf(width, 1.0)))
	style.set_corner_radius_all(CORNER_RADIUS)
	style.draw(get_canvas_item(), rect)
