## Settings overlay dialog. Follows the same CanvasLayer pattern as InitialSetupDialog.
class_name SettingsDialog
extends CanvasLayer

const _AppMessage := preload("res://scripts/ui/app_message.gd")

signal closed
signal settings_applied

@onready var _scale_slider: HSlider = %ScaleSlider
@onready var _scale_value: Label = %ScaleValue
@onready var _scale_hint: Label = %ScaleHint
@onready var _use_system_scale_check: CheckButton = %UseSystemScaleCheck
@onready var _newest_first_check: CheckButton = %NewestFirstCheck
@onready var _save_button: Button = %SaveButton

var _original_scale: float = 1.0
var _original_newest_first: bool = true
var _original_use_system_scale: bool = true
var _viewport_scale_at_open: float = 1.0


func _ready() -> void:
	_viewport_scale_at_open = get_tree().root.content_scale_factor
	_load_current_settings()
	_update_scale_controls()
	_scale_hint.text = "UI scale applies immediately when you save."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _load_current_settings() -> void:
	var scale_str := Database.get_setting(DbConstants.SETTING_UI_SCALE, "1.0")
	_original_use_system_scale = UiScaleSettings.uses_system_default(scale_str)
	_use_system_scale_check.button_pressed = _original_use_system_scale

	if _original_use_system_scale:
		var detected: Dictionary = UiScaleSettings.resolve("1.0")
		_original_scale = float(detected.get("scale", 1.0))
	else:
		_original_scale = scale_str.to_float()
		if _original_scale < 0.5:
			_original_scale = 1.0

	_scale_slider.value = clampf(_original_scale, _scale_slider.min_value, _scale_slider.max_value)

	_original_newest_first = JournalService.get_sort_newest_first()
	_newest_first_check.button_pressed = _original_newest_first


func _on_scale_slider_changed(_value: float) -> void:
	if _use_system_scale_check.button_pressed:
		return
	_preview_manual_scale(_scale_slider.value)


func _on_use_system_scale_toggled(_pressed: bool) -> void:
	_update_scale_controls()
	if _use_system_scale_check.button_pressed:
		_preview_system_scale()
	else:
		_preview_manual_scale(_scale_slider.value)


func _update_scale_controls() -> void:
	var use_system := _use_system_scale_check.button_pressed
	_scale_slider.disabled = use_system
	if use_system:
		var detected: Dictionary = UiScaleSettings.resolve("1.0")
		var scale := float(detected.get("scale", 1.0))
		_scale_slider.value = clampf(scale, _scale_slider.min_value, _scale_slider.max_value)
		_scale_value.text = "%.2f (system)" % scale
	else:
		_update_scale_label(_scale_slider.value)


func _update_scale_label(value: float) -> void:
	_scale_value.text = "%.2f" % value


func _preview_manual_scale(value: float) -> void:
	var scale := clampf(value, 0.5, 4.0)
	get_tree().root.content_scale_factor = scale
	_update_scale_label(value)


func _preview_system_scale() -> void:
	var detected: Dictionary = UiScaleSettings.resolve("1.0")
	var scale := float(detected.get("scale", 1.0))
	get_tree().root.content_scale_factor = scale
	_scale_value.text = "%.2f (system)" % scale


func _restore_viewport_scale() -> void:
	get_tree().root.content_scale_factor = _viewport_scale_at_open


func _on_cancel_pressed() -> void:
	_restore_viewport_scale()
	closed.emit()
	queue_free()


func _on_save_pressed() -> void:
	var new_newest_first := _newest_first_check.button_pressed
	var use_system := _use_system_scale_check.button_pressed

	var changed := false
	var save_failed := false

	if use_system != _original_use_system_scale or (
		not use_system and abs(_scale_slider.value - _original_scale) > 0.001
	):
		if use_system:
			if UiScaleSettings.persist_system_default():
				UiScaleSettings.apply_to_viewport(get_tree(), "1.0")
				changed = true
			else:
				save_failed = true
		elif UiScaleSettings.persist_manual_scale(_scale_slider.value):
			UiScaleSettings.apply_to_viewport(get_tree(), "%.2f" % _scale_slider.value)
			changed = true
		else:
			save_failed = true

	if new_newest_first != _original_newest_first and not save_failed:
		if JournalService.set_sort_newest_first(new_newest_first):
			var main := get_tree().current_scene as Control
			if main:
				var journal := main.find_child("JournalArea", true, false) as Node
				if journal and journal.has_method("refresh_list_deferred"):
					journal.call("refresh_list_deferred")
			changed = true
		else:
			save_failed = true

	if save_failed:
		_restore_viewport_scale()
		_AppMessage.show_save_failed(self, "settings")
		return

	if changed:
		settings_applied.emit()

	if changed and OS.is_debug_build():
		var scale_info: Dictionary = UiScaleSettings.resolve()
		print(
			"Settings saved — UI scale: %.2f (%s), newest_first: %s"
			% [
				scale_info.get("scale", 1.0),
				scale_info.get("source", ""),
				new_newest_first,
			]
		)

	closed.emit()
	queue_free()
