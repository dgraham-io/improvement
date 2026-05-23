## Pure helpers for persisting/restoring desktop window layout.
class_name WindowLayoutLogic
extends RefCounted


static func persistable_mode(mode: Window.Mode) -> Window.Mode:
	if mode == Window.MODE_MINIMIZED:
		return Window.MODE_WINDOWED
	return mode


static func restore_mode(mode: Window.Mode) -> Window.Mode:
	return persistable_mode(mode)


static func clamp_position_to_screen(position: Vector2i, size: Vector2i, screen: Rect2i) -> Vector2i:
	if screen.size.x <= 0 or screen.size.y <= 0:
		return position
	var max_x := screen.position.x + screen.size.x - mini(size.x, screen.size.x)
	var max_y := screen.position.y + screen.size.y - mini(size.y, screen.size.y)
	return Vector2i(
		clampi(position.x, screen.position.x, maxi(screen.position.x, max_x)),
		clampi(position.y, screen.position.y, maxi(screen.position.y, max_y))
	)
