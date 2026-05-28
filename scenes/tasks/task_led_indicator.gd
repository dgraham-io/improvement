## Vertical rounded-rect LED: lit while this task has an active pomodoro.
class_name TaskLedIndicator
extends Control

const LED_SIZE := Vector2(12, 26)
const CORNER_RADIUS := 6
const PULSE_PERIOD_SEC := 1.6
const PULSE_AMOUNT := 0.5

var _active := false
var _palette_host: Control
var _t: float = 0.0


func _ready() -> void:
	_palette_host = _find_palette_host()
	custom_minimum_size = LED_SIZE + Vector2(8, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(_active)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta / PULSE_PERIOD_SEC
	if _t >= 1.0:
		_t -= 1.0
	queue_redraw()


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	set_process(_active)
	queue_redraw()


func _pulse_factor() -> float:
	# Sine breathing in [1 - PULSE_AMOUNT, 1].
	var phase := sin(_t * TAU)
	return 1.0 - PULSE_AMOUNT * 0.5 + (PULSE_AMOUNT * 0.5) * phase


func _find_palette_host() -> Control:
	var node: Node = self
	while node != null:
		if node is Control:
			return node as Control
		node = node.get_parent()
	return self


func _palette_color(key: StringName) -> Color:
	return ThemePalette.color(_palette_host, key, ImprovementThemeTypes.TASK_LED)


func _draw() -> void:
	if _active:
		_draw_lit_led(false)
	else:
		_draw_off_led()


func _led_rect(size_scale: Vector2 = Vector2.ONE) -> Rect2:
	var led_size := Vector2(LED_SIZE.x * size_scale.x, LED_SIZE.y * size_scale.y)
	return Rect2(size * 0.5 - led_size * 0.5, led_size)


func _draw_lit_led(hovered: bool) -> void:
	var glow := _palette_color(ImprovementThemeTypes.LED_GLOW)
	var core := _palette_color(ImprovementThemeTypes.LED_CORE)
	var p := _pulse_factor()
	var glow_scale := 1.1 if hovered else (1.0 + 0.05 * (p - 0.75))
	_draw_rounded_fill(_led_rect(Vector2(1.22 * glow_scale, 1.2 * glow_scale)), Color(glow, 0.14 * p))
	_draw_rounded_fill(_led_rect(Vector2(1.08 * glow_scale, 1.08 * glow_scale)), Color(glow, 0.24 * p))
	_draw_rounded_border(_led_rect(), glow, 0.55 * p, 1.25)
	_draw_rounded_fill(_led_rect(Vector2(0.76, 0.76)), core)
	var core_rect := _led_rect(Vector2(0.76, 0.76))
	var spec := Rect2(
		core_rect.position + Vector2(core_rect.size.x * 0.12, core_rect.size.y * 0.1),
		Vector2(core_rect.size.x * 0.45, core_rect.size.y * 0.22)
	)
	_draw_rounded_fill(
		spec,
		_palette_color(ImprovementThemeTypes.LED_SPECULAR),
		CORNER_RADIUS / 2
	)


func _draw_off_led() -> void:
	_draw_rounded_fill(_led_rect(), _palette_color(ImprovementThemeTypes.LED_OFF_FILL))
	_draw_rounded_border(
		_led_rect(),
		_palette_color(ImprovementThemeTypes.LED_OFF_BORDER),
		1.0,
		1.0
	)
	var inner := _led_rect(Vector2(0.7, 0.55))
	inner.position.y += LED_SIZE.y * 0.08
	_draw_rounded_fill(
		inner,
		_palette_color(ImprovementThemeTypes.LED_INNER_SHADOW),
		CORNER_RADIUS - 2
	)


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
