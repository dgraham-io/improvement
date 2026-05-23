## Autoload: plays feedback sounds for app events.
extends Node

const POMODORO_ENDED_STREAM := preload("res://assets/sounds/question_004.ogg")

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = POMODORO_ENDED_STREAM
	add_child(_player)
	PomodoroService.session_ended.connect(_on_pomodoro_session_ended)


func _on_pomodoro_session_ended(_target_type: String, _target_id: int, completed: bool) -> void:
	if not completed:
		return
	_player.stop()
	_player.play()
