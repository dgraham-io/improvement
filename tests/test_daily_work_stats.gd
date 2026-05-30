## GUT tests for daily pomodoro work aggregation.
extends GutTest

const DatabaseScript := preload("res://scripts/autoload/database.gd")
const TimeFmt := preload("res://scripts/util/time_format.gd")

var _db: Node
var _test_dir: String = ""


func before_each() -> void:
	_test_dir = _make_temp_directory()
	_db = DatabaseScript.new()
	_db._db = null
	_db.is_ready = false
	add_child_autofree(_db)
	assert_true(_db._initialize(_test_dir))


func after_each() -> void:
	_remove_directory_recursive(_test_dir)


func test_local_day_start_normalizes_to_local_midnight() -> void:
	var tz := Time.get_time_zone_from_system()
	var offset_sec: int = tz.get("bias", 0) * 60

	var sample := 1_700_000_000
	var day_start := TimeFmt.local_day_start(sample)

	# The returned unix time, when interpreted in local time, must be midnight.
	var local_parts := Time.get_datetime_dict_from_unix_time(day_start - offset_sec)
	assert_eq(local_parts.hour, 0, "local_day_start must produce local midnight (hour)")
	assert_eq(local_parts.minute, 0, "local_day_start must produce local midnight (minute)")
	assert_eq(local_parts.second, 0, "local_day_start must produce local midnight (second)")

	# Idempotent
	assert_eq(TimeFmt.local_day_start(day_start), day_start)


func test_format_day_heading_today_and_yesterday() -> void:
	var now := int(Time.get_unix_time_from_system())
	var today := TimeFmt.local_day_start(now)
	assert_eq(TimeFmt.format_day_heading(today), "Today")
	assert_eq(TimeFmt.format_day_heading(today - 86400), "Yesterday")


func test_fetch_daily_pomodoro_stats_sums_sessions_on_same_day() -> void:
	var day_anchor := TimeFmt.local_day_start(int(Time.get_unix_time_from_system()))
	var journal_id: int = _db.insert_journal_entry("metrics test")
	var task_id: int = _db.insert_task("task", "", DbConstants.TASK_PENDING, 0, 0, 0)
	assert_gt(journal_id, 0)
	assert_gt(task_id, 0)
	var session_a: int = _db.insert_pomodoro_session(DbConstants.TARGET_JOURNAL, journal_id)
	var session_b: int = _db.insert_pomodoro_session(DbConstants.TARGET_TASK, task_id)
	assert_gt(session_a, 0)
	assert_gt(session_b, 0)
	var now := int(Time.get_unix_time_from_system())
	_db._db.query_with_bindings(
		"UPDATE pomodoro_sessions SET started_at = ?, ended_at = ?, completed = 1 WHERE id = ?;",
		[now - 1500, now, session_a]
	)
	_db._db.query_with_bindings(
		"UPDATE pomodoro_sessions SET started_at = ?, ended_at = ?, completed = 0 WHERE id = ?;",
		[now - 900, now, session_b]
	)
	var stats: Dictionary = _db.fetch_daily_pomodoro_stats(day_anchor)
	assert_eq(int(stats.get("session_count", 0)), 2)
	assert_eq(int(stats.get("completed_pomodoros", 0)), 1)
	assert_eq(int(stats.get("total_work_sec", 0)), 2400)
	assert_eq(int(stats.get("journal_work_sec", 0)), 1500)
	assert_eq(int(stats.get("task_work_sec", 0)), 900)
	var hourly: PackedInt32Array = stats.get("hourly_work_sec", PackedInt32Array())
	assert_eq(hourly.size(), 24)


func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_daily_%d" % Time.get_ticks_usec()
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(path), OK)
	return path


func _remove_directory_recursive(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var root := DirAccess.open(path)
	if root == null:
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full := path.path_join(entry)
			if root.current_is_dir():
				_remove_directory_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		entry = root.get_next()
	root.list_dir_end()
	DirAccess.remove_absolute(path)
