## GUT tests for PomodoroService target binding and session lifecycle (no autoload).
extends GutTest

const PomodoroServiceScript := preload("res://scripts/autoload/pomodoro_service.gd")

var _pomo: Node


func before_each() -> void:
	_pomo = PomodoroServiceScript.new()
	add_child_autofree(_pomo)


func test_can_start_for_journal_and_task_only() -> void:
	assert_true(_pomo.can_start_for(DbConstants.TARGET_JOURNAL, 1))
	assert_true(_pomo.can_start_for(DbConstants.TARGET_TASK, 1))
	assert_false(_pomo.can_start_for(DbConstants.TARGET_NONE, 0))
	assert_false(_pomo.can_start_for("todo", 1), "legacy todo target type must not be accepted")


func test_is_active_target_matches_running_session() -> void:
	_pomo._session_id = 7
	_pomo.active_target_type = DbConstants.TARGET_TASK
	_pomo.active_target_id = 3
	assert_true(_pomo.is_active_target(DbConstants.TARGET_TASK, 3))
	assert_false(_pomo.is_active_target(DbConstants.TARGET_TASK, 4))
	assert_false(_pomo.is_active_target(DbConstants.TARGET_JOURNAL, 3))
	assert_false(_pomo.is_active_target("todo", 3))


func test_has_active_task_session_when_task_target_running() -> void:
	_pomo._session_id = 1
	_pomo.active_target_type = DbConstants.TARGET_TASK
	assert_true(_pomo.has_active_task_session())
	_pomo.active_target_type = DbConstants.TARGET_JOURNAL
	assert_false(_pomo.has_active_task_session())
	_pomo._session_id = 0
	assert_false(_pomo.has_active_task_session())


func test_pause_resume_updates_running_state() -> void:
	_pomo._session_id = 1
	_pomo.is_running = true
	_pomo.is_paused = false
	_pomo._end_at_unix = int(Time.get_unix_time_from_system()) + 120
	_pomo.set_process(true)

	_pomo.pause()
	assert_false(_pomo.is_running)
	assert_true(_pomo.is_paused)
	assert_lte(_pomo.remaining_sec, 120)

	_pomo.resume()
	assert_true(_pomo.is_running)
	assert_false(_pomo.is_paused)


func test_stop_clears_active_target_and_emits_session_ended() -> void:
	# _session_id left at 0 so stop() does not call Database (test has no DB wiring).
	_pomo.active_target_type = DbConstants.TARGET_TASK
	_pomo.active_target_id = 5
	_pomo.is_running = true
	watch_signals(_pomo)

	_pomo.stop(false)

	assert_eq(_pomo._session_id, 0)
	assert_eq(_pomo.active_target_type, DbConstants.TARGET_NONE)
	assert_eq(_pomo.active_target_id, 0)
	assert_false(_pomo.is_running)
	assert_signal_emit_count(_pomo, "session_ended", 1)
