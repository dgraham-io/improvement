## Detects appropriate UI scale for the current system.
## Used by main.gd. Extracted for testability.
class_name UiScaleDetector
extends RefCounted


const DEFAULT_SCALE := 1.0


## Returns a Dictionary with "scale" and "source" keys.
static func detect() -> Dictionary:
	var result := {"scale": DEFAULT_SCALE, "source": "default"}
	
	# Try system detection with fallbacks
	var detection := _detect_system_scale()
	result.scale = detection.scale
	result.source = detection.source
	
	# Final safety clamp
	result.scale = clamp(result.scale, 0.5, 4.0)
	
	return result


static func _detect_system_scale() -> Dictionary:
	var result := {"scale": DEFAULT_SCALE, "source": "none"}
	
	var screen := DisplayServer.window_get_current_screen()
	if screen < 0:
		screen = 0
	
	# Method 1: Godot's built-in scale
	var base_scale := DisplayServer.screen_get_scale(screen)
	result.scale = base_scale
	result.source = "system (screen %d)" % screen
	
	# Method 2: DPI fallback (important on Linux)
	if base_scale <= 1.05:
		var dpi := DisplayServer.screen_get_dpi(screen)
		if dpi > 120:
			# Use 120 DPI as reference (more conservative on high-DPI Linux)
			var dpi_scale := dpi / 120.0
			result.scale = dpi_scale
			result.source = "DPI fallback (dpi=%d)" % dpi
	
	# Method 3: Common Linux environment variables
	var gdk_scale := OS.get_environment("GDK_SCALE")
	if not gdk_scale.is_empty():
		var env_scale := gdk_scale.to_float()
		if env_scale > 0.5:
			result.scale = max(result.scale, env_scale)
			result.source += " + GDK_SCALE"
	
	var gdk_dpi_scale := OS.get_environment("GDK_DPI_SCALE")
	if not gdk_dpi_scale.is_empty():
		var env_scale := gdk_dpi_scale.to_float()
		if env_scale > 0.5:
			result.scale = max(result.scale, env_scale)
			result.source += " + GDK_DPI_SCALE"
	
	return result
