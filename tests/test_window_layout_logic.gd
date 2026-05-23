## GUT tests for window layout persistence helpers.
extends GutTest

const WindowLayoutLogic := preload("res://scripts/ui/window_layout_logic.gd")


func test_persistable_mode_maps_minimized_to_windowed() -> void:
	assert_eq(
		WindowLayoutLogic.persistable_mode(Window.MODE_MINIMIZED),
		Window.MODE_WINDOWED
	)
	assert_eq(
		WindowLayoutLogic.persistable_mode(Window.MODE_MAXIMIZED),
		Window.MODE_MAXIMIZED
	)


func test_clamp_position_keeps_window_on_screen() -> void:
	var screen := Rect2i(0, 0, 1280, 720)
	var size := Vector2i(800, 600)
	var clamped := WindowLayoutLogic.clamp_position_to_screen(
		Vector2i(-200, 900), size, screen
	)
	assert_gte(clamped.x, screen.position.x)
	assert_lte(clamped.x, screen.position.x + screen.size.x - size.x)
	assert_gte(clamped.y, screen.position.y)
	assert_lte(clamped.y, screen.position.y + screen.size.y - size.y)
