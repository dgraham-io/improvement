## Single active Pomodoro countdown; persists sessions via Database.
extends Node

const _DailyWorkStats := preload("res://scripts/models/daily_work_stats.gd")

signal state_changed
signal session_ended(target_type: String, target_id: int, completed: bool)

var active_target_type: String = DbConstants.TARGET_NONE
var active_target_id: int = 0
var remaining_sec: int = PomodoroSession.DEFAULT_DURATION_SEC
var is_running: bool = false
var is_paused: bool = false

var _session_id: int = 0
var _end_at_unix: int = 0


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	if not Database.is_ready:
		return
	set_process(false)


func is_active_target(target_type: String, target_id: int) -> bool:
	if _session_id <= 0:
		return false
	if active_target_type != target_type:
		return false
	return active_target_id == target_id


func can_start_for(target_type: String, _target_id: int) -> bool:
	return target_type == DbConstants.TARGET_JOURNAL or target_type == DbConstants.TARGET_TASK


func start_for(target_type: String, target_id: int) -> bool:
	if not Database.is_ready:
		return false
	if not can_start_for(target_type, target_id):
		return false
	if _session_id > 0:
		stop(false)
	var session_id := Database.insert_pomodoro_session(target_type, target_id)
	if session_id <= 0:
		push_error("PomodoroService: could not create session (%s #%d)" % [target_type, target_id])
		return false
	_session_id = session_id
	active_target_type = target_type
	active_target_id = target_id
	remaining_sec = PomodoroSession.DEFAULT_DURATION_SEC
	is_running = true
	is_paused = false
	_end_at_unix = int(Time.get_unix_time_from_system()) + remaining_sec
	set_process(true)
	_mark_task_in_progress_if_needed(target_type, target_id)
	state_changed.emit()
	return true


func _mark_task_in_progress_if_needed(target_type: String, target_id: int) -> void:
	if target_type != DbConstants.TARGET_TASK or target_id <= 0:
		return
	var todo: TodoItem = TaskService.get_todo(target_id)
	if todo == null or todo.status != DbConstants.TASK_PENDING:
		return
	TaskService.set_status(target_id, DbConstants.TASK_IN_PROGRESS)


func attach_target(target_type: String, target_id: int) -> void:
	if _session_id <= 0 or target_id <= 0:
		return
	if active_target_type != target_type:
		return
	if active_target_id == target_id:
		return
	if not Database.update_pomodoro_session_target(_session_id, target_id):
		return
	active_target_id = target_id
	state_changed.emit()


func pause() -> void:
	if not is_running:
		return
	remaining_sec = maxi(0, _end_at_unix - int(Time.get_unix_time_from_system()))
	is_running = false
	is_paused = true
	set_process(false)
	state_changed.emit()


func resume() -> void:
	if not is_paused or _session_id <= 0:
		return
	is_running = true
	is_paused = false
	_end_at_unix = int(Time.get_unix_time_from_system()) + remaining_sec
	set_process(true)
	state_changed.emit()


func stop(mark_complete: bool = false) -> void:
	var ended_type := active_target_type
	var ended_id := active_target_id
	if _session_id > 0:
		Database.complete_pomodoro_session(_session_id, mark_complete)
	_session_id = 0
	active_target_type = DbConstants.TARGET_NONE
	active_target_id = 0
	remaining_sec = PomodoroSession.DEFAULT_DURATION_SEC
	is_running = false
	is_paused = false
	_end_at_unix = 0
	set_process(false)
	state_changed.emit()
	if ended_type != DbConstants.TARGET_NONE and ended_id > 0:
		session_ended.emit(ended_type, ended_id, mark_complete)


func stop_if_journal() -> void:
	if active_target_type == DbConstants.TARGET_JOURNAL:
		stop(false)


func has_active_task_session() -> bool:
	return _session_id > 0 and active_target_type == DbConstants.TARGET_TASK


func get_daily_work_stats(day_start_unix: int):
	var data := Database.fetch_daily_pomodoro_stats(day_start_unix)
	return _DailyWorkStats.from_dictionary(day_start_unix, data)


func _process(_delta: float) -> void:
	if not is_running or _session_id <= 0:
		return
	remaining_sec = maxi(0, _end_at_unix - int(Time.get_unix_time_from_system()))
	state_changed.emit()
	if remaining_sec <= 0:
		stop(true)
