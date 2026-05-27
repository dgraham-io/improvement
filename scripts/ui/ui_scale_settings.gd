## Resolves and applies UI scale from app_settings (manual override vs system detection).
class_name UiScaleSettings
extends RefCounted


static func uses_system_default(stored_value: String) -> bool:
	if stored_value.is_empty():
		return true
	var parsed := stored_value.to_float()
	return parsed <= 0.25 or abs(parsed - 1.0) <= 0.01


static func resolve(stored_value: String = "") -> Dictionary:
	var scale := 1.0
	var source := "default"
	if stored_value.is_empty() and Database.is_ready:
		stored_value = Database.get_setting(DbConstants.SETTING_UI_SCALE, "")
	if not stored_value.is_empty() and not uses_system_default(stored_value):
		var parsed := stored_value.to_float()
		if parsed > 0.25:
			scale = parsed
			source = "stored setting"
	if source == "default":
		var detection := UiScaleDetector.detect()
		scale = detection.scale
		source = detection.source
	scale = clampf(scale, 0.5, 4.0)
	return {"scale": scale, "source": source}


static func apply_to_viewport(tree: SceneTree, stored_value: String = "") -> Dictionary:
	var resolved := resolve(stored_value)
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = resolved.scale
	return resolved


static func persist_manual_scale(scale: float) -> bool:
	return Database.set_setting(DbConstants.SETTING_UI_SCALE, "%.2f" % clampf(scale, 0.5, 4.0))


static func persist_system_default() -> bool:
	return Database.set_setting(DbConstants.SETTING_UI_SCALE, "1.0")
