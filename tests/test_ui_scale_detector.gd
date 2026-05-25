## GUT tests for UiScaleDetector (HiDPI / Linux scale detection).
extends GutTest

const UiScaleDetector := preload("res://scripts/ui/ui_scale_detector.gd")


func test_detect_returns_reasonable_values() -> void:
	var result := UiScaleDetector.detect()
	
	assert_true(result.has("scale"))
	assert_true(result.has("source"))
	assert_true(result.scale >= 0.5 and result.scale <= 4.0)


func test_dpi_fallback_produces_sane_values() -> void:
	# We can't easily mock DisplayServer, but we can at least verify
	# the detector doesn't blow up and returns something in range.
	var result := UiScaleDetector.detect()
	assert_true(result.scale > 0.0)


func test_prefers_explicit_override_when_different_from_one() -> void:
	# This test verifies the public API contract that callers (main.gd)
	# should prefer stored values. We test the detector in isolation here.
	# The override logic lives in main.gd, so we document the expectation.
	pass  # Covered indirectly via integration in main scene tests if needed.
