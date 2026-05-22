## Compact Pomodoro control bound to one journal entry or todo.
class_name PomodoroTimerWidget
extends HBoxContainer

@onready var _time_label: Label = $TimeLabel
@onready var _action_button: Button = $ActionButton

var _target_type: String = DbConstants.TARGET_NONE
var _target_id: int = 0
var _enabled: bool = false


func _ready() -> void:
	if PomodoroService.state_changed.is_connected(_refresh):
		PomodoroService.state_changed.disconnect(_refresh)
	PomodoroService.state_changed.connect(_refresh)
	if _action_button.pressed.is_connected(_on_action_pressed):
		_action_button.pressed.disconnect(_on_action_pressed)
	_action_button.pressed.connect(_on_action_pressed)
	_refresh()


func bind(target_type: String, target_id: int, enabled: bool = true) -> void:
	_target_type = target_type
	_target_id = target_id
	_enabled = enabled
	_refresh()


func _on_action_pressed() -> void:
	if not _enabled or _action_button == null:
		return
	if PomodoroService.is_active_target(_target_type, _target_id):
		if PomodoroService.is_running:
			PomodoroService.pause()
		elif PomodoroService.is_paused:
			PomodoroService.resume()
		else:
			PomodoroService.stop(false)
		return
	if PomodoroService.can_start_for(_target_type, _target_id):
		if not PomodoroService.start_for(_target_type, _target_id):
			push_warning("Pomodoro failed to start for %s #%d" % [_target_type, _target_id])


func _refresh() -> void:
	if _time_label == null or _action_button == null:
		return
	if not _enabled or not PomodoroService.can_start_for(_target_type, _target_id):
		_time_label.text = _format_time(PomodoroSession.DEFAULT_DURATION_SEC)
		_action_button.text = "Start"
		_action_button.disabled = true
		_action_button.tooltip_text = ""
		return
	if PomodoroService.is_active_target(_target_type, _target_id):
		_time_label.text = _format_time(PomodoroService.remaining_sec)
		if PomodoroService.is_running:
			_action_button.text = "Pause"
		elif PomodoroService.is_paused:
			_action_button.text = "Resume"
		else:
			_action_button.text = "Stop"
		_action_button.disabled = false
		_action_button.tooltip_text = ""
	else:
		_time_label.text = _format_time(PomodoroSession.DEFAULT_DURATION_SEC)
		_action_button.text = "Start"
		_action_button.disabled = false
		_action_button.tooltip_text = "Start 25-minute focus timer"


func _format_time(total_sec: int) -> String:
	var safe := maxi(0, total_sec)
	var minutes := safe / 60
	var seconds := safe % 60
	return "%d:%02d" % [minutes, seconds]
