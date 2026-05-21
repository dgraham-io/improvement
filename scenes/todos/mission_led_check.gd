## Vertical rounded-rect LED: lit while active, dim when done.
class_name MissionLedCheck
extends CheckBox

const LED_SIZE := Vector2(12, 26)
const CORNER_RADIUS := 6
const GLOW_COLOR := Color(0.133333, 0.866667, 1, 1)
const CORE_COLOR := Color(0.55, 0.98, 1, 1)
const OFF_FILL := Color(0.06, 0.08, 0.14, 1)
const OFF_BORDER := Color(0.28, 0.32, 0.42, 0.55)

var _empty_icon: ImageTexture
var _empty_style: StyleBoxEmpty


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = LED_SIZE + Vector2(8, 8)
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("outline_size", 0)
	add_theme_constant_override("check_v_offset", 0)
	_ensure_assets()
	_apply_icon_overrides()
	_apply_focus_override()
	toggled.connect(func(_on: bool) -> void: queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


func _ensure_assets() -> void:
	if _empty_icon == null:
		var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		_empty_icon = ImageTexture.create_from_image(img)
	if _empty_style == null:
		_empty_style = StyleBoxEmpty.new()


func _apply_icon_overrides() -> void:
	_ensure_assets()
	for icon_name: StringName in [
		&"checked",
		&"unchecked",
		&"checked_disabled",
		&"unchecked_disabled",
		&"radio_checked",
		&"radio_unchecked",
	]:
		add_theme_icon_override(icon_name, _empty_icon)


func _apply_focus_override() -> void:
	_ensure_assets()
	add_theme_stylebox_override(&"focus", _empty_style)
	add_theme_stylebox_override(&"hover", _empty_style)
	add_theme_stylebox_override(&"pressed", _empty_style)
	add_theme_stylebox_override(&"normal", _empty_style)


func _is_lit() -> bool:
	return not button_pressed


func _led_rect(size_scale: Vector2 = Vector2.ONE) -> Rect2:
	var led_size := Vector2(LED_SIZE.x * size_scale.x, LED_SIZE.y * size_scale.y)
	return Rect2(_led_center() - led_size * 0.5, led_size)


func _led_center() -> Vector2:
	return size * 0.5


func _draw() -> void:
	if _is_lit():
		_draw_lit_led(is_hovered())
		if has_focus():
			_draw_rounded_border(_led_rect(Vector2(1.14, 1.1)), GLOW_COLOR, 0.45, 1.0)
	else:
		_draw_off_led()


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
	_draw_rounded_fill(spec, Color(1, 1, 1, 0.5 if hovered else 0.38), CORNER_RADIUS / 2)


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
