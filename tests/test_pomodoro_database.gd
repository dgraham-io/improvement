## GUT tests for Pomodoro persistence and v6 target_type migration (todo → task).
extends GutTest

const DatabaseScript := preload("res://scripts/autoload/database.gd")

var _db: Node
var _test_dir: String = ""


func before_each() -> void:
	_test_dir = _make_temp_directory()
	_db = DatabaseScript.new()
	_db._db = null
	_db.is_ready = false
	add_child_autofree(_db)


func after_each() -> void:
	_db._db = null
	_db.is_ready = false
	await wait_process_frames(2)
	_remove_directory_recursive(_test_dir)


func test_pomodoro_target_constants_use_task_not_todo() -> void:
	var values := DbConstants.pomodoro_target_values()
	assert_true(values.has(DbConstants.TARGET_TASK))
	assert_false(values.has("todo"))


func test_fresh_db_insert_pomodoro_session_for_task_and_journal() -> void:
	assert_true(_db._initialize(_test_dir))
	var journal_id: int = _db.insert_journal_entry("pomodoro journal")
	var task_id: int = _db.insert_todo("pomodoro task", "", DbConstants.TASK_PENDING, 0, 0, 0)
	assert_gt(journal_id, 0)
	assert_gt(task_id, 0)

	var journal_session: int = _db.insert_pomodoro_session(DbConstants.TARGET_JOURNAL, journal_id)
	var task_session: int = _db.insert_pomodoro_session(DbConstants.TARGET_TASK, task_id)
	assert_gt(journal_session, 0, "journal pomodoro session should insert")
	assert_gt(task_session, 0, "task pomodoro session should insert")

	assert_string_contains(_pomodoro_create_sql(), "'task'")
	assert_false(_pomodoro_create_sql().contains("'todo'"))


func test_legacy_schema_rejects_task_target_type_before_v6() -> void:
	_setup_legacy_v5_pomodoro_table()
	var now := int(Time.get_unix_time_from_system())
	var ok: bool = _db._db.query_with_bindings(
		"INSERT INTO pomodoro_sessions "
		+ "(started_at, planned_duration_sec, target_type, target_id, completed) "
		+ "VALUES (?, ?, ?, ?, 0);",
		[now, PomodoroSession.DEFAULT_DURATION_SEC, DbConstants.TARGET_TASK, 1]
	)
	assert_false(ok, "legacy CHECK should reject target_type task")
	assert_engine_error("CHECK constraint failed")


func test_migrate_v6_allows_task_pomodoro_and_converts_todo_rows() -> void:
	_setup_legacy_v5_pomodoro_table()
	var now := int(Time.get_unix_time_from_system())
	assert_true(
		_db._db.query_with_bindings(
			"INSERT INTO pomodoro_sessions "
			+ "(started_at, planned_duration_sec, target_type, target_id, completed) "
			+ "VALUES (?, ?, ?, ?, 0);",
			[now, PomodoroSession.DEFAULT_DURATION_SEC, "todo", 42]
		)
	)

	_db._migrate_to_v6()

	var create_sql := _pomodoro_create_sql()
	assert_string_contains(create_sql, "'task'")
	assert_false(create_sql.contains("'todo'"))

	assert_true(
		_db._db.query(
			"SELECT target_type FROM pomodoro_sessions WHERE target_id = 42 LIMIT 1;"
		)
	)
	assert_eq(str(_db._db.query_result[0].get("target_type", "")), DbConstants.TARGET_TASK)

	var task_session: int = _db.insert_pomodoro_session(DbConstants.TARGET_TASK, 99)
	assert_gt(task_session, 0, "task pomodoro should insert after v6 migration")


func test_full_migrate_from_v5_runs_v6_and_allows_task_insert() -> void:
	_setup_legacy_v5_pomodoro_table()
	_db._migrate()
	assert_eq(_db._get_user_version(), DbConstants.SCHEMA_VERSION)

	var session_id: int = _db.insert_pomodoro_session(DbConstants.TARGET_TASK, 1)
	assert_gt(session_id, 0, "v6 schema should accept task pomodoro after _migrate()")


func test_migrate_v6_idempotent_on_modern_schema() -> void:
	assert_true(_db._initialize(_test_dir))
	var task_id: int = _db.insert_todo("idempotent", "", DbConstants.TASK_PENDING, 0, 0, 0)
	assert_gt(task_id, 0)

	_db._migrate_to_v6()
	var first: int = _db.insert_pomodoro_session(DbConstants.TARGET_TASK, task_id)
	_db._migrate_to_v6()
	var second: int = _db.insert_pomodoro_session(DbConstants.TARGET_TASK, task_id)
	assert_gt(first, 0)
	assert_gt(second, 0)


func _setup_legacy_v5_pomodoro_table() -> void:
	assert_true(_db._open_at_directory(_test_dir))
	assert_true(_db._db.query("PRAGMA user_version = 5;"))
	assert_true(
		_db._db.query(
			"""CREATE TABLE pomodoro_sessions (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				started_at INTEGER NOT NULL,
				ended_at INTEGER,
				planned_duration_sec INTEGER NOT NULL DEFAULT 1500,
				target_type TEXT NOT NULL DEFAULT 'none'
					CHECK (target_type IN ('none', 'journal', 'todo')),
				target_id INTEGER,
				completed INTEGER NOT NULL DEFAULT 0
					CHECK (completed IN (0, 1))
			);"""
		)
	)


func _pomodoro_create_sql() -> String:
	if not _db._db.query(
		"SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'pomodoro_sessions' LIMIT 1;"
	):
		return ""
	if _db._db.query_result.is_empty():
		return ""
	return str(_db._db.query_result[0].get("sql", ""))


func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_pomodoro_%d" % Time.get_ticks_usec()
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
