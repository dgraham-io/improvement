## Settings overlay dialog. Follows the same CanvasLayer pattern as InitialSetupDialog.
class_name SettingsDialog
extends CanvasLayer

const _AppMessage := preload("res://scripts/ui/app_message.gd")

signal closed

@onready var _scale_slider: HSlider = %ScaleSlider
@onready var _scale_value: Label = %ScaleValue
@onready var _scale_hint: Label = %ScaleHint
@onready var _newest_first_check: CheckButton = %NewestFirstCheck
@onready var _save_button: Button = %SaveButton

var _original_scale: float = 1.0
var _original_newest_first: bool = true


func _ready() -> void:
	_load_current_settings()
	_update_scale_label(_scale_slider.value)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _load_current_settings() -> void:
	# UI Scale
	var scale_str := Database.get_setting(DbConstants.SETTING_UI_SCALE, "1.0")
	var parsed := scale_str.to_float()
	if parsed < 0.5:
		parsed = 1.0
	_original_scale = parsed
	_scale_slider.value = clamp(parsed, 0.75, 2.5)

	# Journal sort
	_original_newest_first = JournalService.get_sort_newest_first()
	_newest_first_check.button_pressed = _original_newest_first


func _on_scale_slider_changed(value: float) -> void:
	_update_scale_label(value)


func _update_scale_label(value: float) -> void:
	_scale_value.text = "%.2f" % value


func _on_cancel_pressed() -> void:
	closed.emit()
	queue_free()


func _on_save_pressed() -> void:
	var new_scale := _scale_slider.value
	var new_newest_first := _newest_first_check.button_pressed

	var changed := false
	var save_failed := false

	# Save UI scale
	if abs(new_scale - _original_scale) > 0.001:
		if Database.set_setting(DbConstants.SETTING_UI_SCALE, "%.2f" % new_scale):
			changed = true
		else:
			save_failed = true

	# Save journal sort
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
		_AppMessage.show_save_failed(self, "settings")
		return

	if changed and OS.is_debug_build():
		print("Settings saved — UI scale: %.2f, newest_first: %s" % [new_scale, new_newest_first])

	closed.emit()
	queue_free()
