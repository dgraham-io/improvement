## GUT tests for UI scale resolution (manual override vs system default).
extends GutTest

const UiScaleSettings := preload("res://scripts/ui/ui_scale_settings.gd")


func test_uses_system_default_for_empty_and_one() -> void:
	assert_true(UiScaleSettings.uses_system_default(""))
	assert_true(UiScaleSettings.uses_system_default("1.0"))
	assert_true(UiScaleSettings.uses_system_default("1.00"))


func test_manual_override_when_stored_differs_from_one() -> void:
	assert_false(UiScaleSettings.uses_system_default("1.25"))


func test_resolve_honors_stored_override() -> void:
	var resolved: Dictionary = UiScaleSettings.resolve("1.5")
	assert_eq(resolved.get("source", ""), "stored setting")
	assert_eq(resolved.get("scale", 0.0), 1.5)


func test_resolve_uses_detection_when_stored_is_system_default() -> void:
	var resolved: Dictionary = UiScaleSettings.resolve("1.0")
	assert_ne(resolved.get("source", ""), "stored setting")
	assert_true(float(resolved.get("scale", 0.0)) >= 0.5)
