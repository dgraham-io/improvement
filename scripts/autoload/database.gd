## Autoload: opens `<db_directory>/improvement.db`, runs migrations, exposes typed data access.
## UI and feature code should use JournalService / TodoService, not query SQL directly.
extends Node

const _DatabaseOpen := preload("res://scripts/database/database_open.gd")

signal ready_changed(is_ready: bool)

var is_ready: bool = false

var _db: SQLite
var _last_open_error: String = ""


func _ready() -> void:
	var db_directory := AppConfig.read_db_directory()
	while not is_ready:
		if db_directory.is_empty():
			db_directory = await AppSetup.setup_completed
		if _initialize(db_directory):
			break
		push_error("Database: failed to open at %s — %s" % [db_directory, _last_open_error])
		db_directory = await AppSetup.request_open_retry(_last_open_error, db_directory)
		if not AppConfig.write_db_directory(db_directory):
			push_error("AppSetup: failed to save app_config.json after open retry")


func _initialize(db_directory: String) -> bool:
	if not _open_at_directory(db_directory):
		return false
	_migrate()
	_apply_default_settings()
	set_setting(DbConstants.SETTING_DB_DIRECTORY, AppConfig.normalize_directory(db_directory))
	is_ready = true
	ready_changed.emit(true)
	return true


func get_db_directory() -> String:
	return AppConfig.normalize_directory(get_setting(DbConstants.SETTING_DB_DIRECTORY, ""))


func get_db_file_path() -> String:
	return AppConfig.db_base_path(get_db_directory()) + ".db"


func _open_at_directory(db_directory: String) -> bool:
	var result: _DatabaseOpen.OpenResult = _DatabaseOpen.try_open_at_directory(db_directory)
	_last_open_error = result.error_message
	if not result.ok:
		_db = null
		return false
	_db = result.sqlite
	return true


func _migrate() -> void:
	var version := _get_user_version()
	if version < 1:
		_migrate_to_v1()
		_set_user_version(1)
		version = 1
	if version < 2:
		_migrate_to_v2()
		_set_user_version(2)
		version = 2
	if version < 3:
		_migrate_to_v3()
		_set_user_version(3)


func _get_user_version() -> int:
	if not _db.query("PRAGMA user_version;"):
		return 0
	if _db.query_result.is_empty():
		return 0
	return int(_db.query_result[0].get("user_version", 0))


func _set_user_version(version: int) -> void:
	_db.query("PRAGMA user_version = %d;" % version)


func _migrate_to_v1() -> void:
	var statements: PackedStringArray = [
		"""CREATE TABLE IF NOT EXISTS journal_entries (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			body TEXT NOT NULL DEFAULT '',
			deleted_at INTEGER
		);""",
		"""CREATE INDEX IF NOT EXISTS idx_journal_entries_active_created
			ON journal_entries (created_at DESC)
			WHERE deleted_at IS NULL;""",
		"""CREATE TABLE IF NOT EXISTS todos (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			title TEXT NOT NULL,
			notes TEXT NOT NULL DEFAULT '',
			status TEXT NOT NULL DEFAULT 'pending'
				CHECK (status IN ('pending', 'in_progress', 'done', 'cancelled')),
			priority INTEGER NOT NULL DEFAULT 0
				CHECK (priority >= 0 AND priority <= 3),
			due_at INTEGER,
			sort_order INTEGER NOT NULL DEFAULT 0,
			journal_entry_id INTEGER REFERENCES journal_entries (id) ON DELETE SET NULL,
			deleted_at INTEGER
		);""",
		"""CREATE INDEX IF NOT EXISTS idx_todos_active_sort
			ON todos (sort_order ASC, created_at DESC)
			WHERE deleted_at IS NULL;""",
		"""CREATE INDEX IF NOT EXISTS idx_todos_active_due
			ON todos (due_at ASC)
			WHERE deleted_at IS NULL AND due_at IS NOT NULL;""",
		"""CREATE TABLE IF NOT EXISTS pomodoro_sessions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			started_at INTEGER NOT NULL,
			ended_at INTEGER,
			planned_duration_sec INTEGER NOT NULL DEFAULT 1500,
			target_type TEXT NOT NULL DEFAULT 'none'
				CHECK (target_type IN ('none', 'journal', 'todo')),
			target_id INTEGER,
			completed INTEGER NOT NULL DEFAULT 0
				CHECK (completed IN (0, 1))
		);""",
		"""CREATE INDEX IF NOT EXISTS idx_pomodoro_started
			ON pomodoro_sessions (started_at DESC);""",
		"""CREATE TABLE IF NOT EXISTS app_settings (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		);""",
	]
	for sql in statements:
		if not _db.query(sql):
			push_error("Migration v1 failed: %s\nSQL: %s" % [_db.error_message, sql])
			return


func _journal_table_has_column(column_name: String) -> bool:
	if not _db.query("PRAGMA table_info(journal_entries);"):
		return false
	for row in _db.query_result:
		if str(row.get("name", "")) == column_name:
			return true
	return false


func _migrate_to_v2() -> void:
	# Skip if mood was never present (fresh DBs created after mood removal).
	if not _journal_table_has_column("mood"):
		return
	# Drop legacy mood column by rebuilding journal_entries (SQLite-safe).
	var statements: PackedStringArray = [
		"""CREATE TABLE journal_entries_v2 (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			title TEXT NOT NULL DEFAULT '',
			body TEXT NOT NULL DEFAULT '',
			deleted_at INTEGER
		);""",
		"""INSERT INTO journal_entries_v2 (id, created_at, updated_at, title, body, deleted_at)
			SELECT id, created_at, updated_at, title, body, deleted_at FROM journal_entries;""",
		"DROP TABLE journal_entries;",
		"ALTER TABLE journal_entries_v2 RENAME TO journal_entries;",
		"""CREATE INDEX IF NOT EXISTS idx_journal_entries_active_created
			ON journal_entries (created_at DESC)
			WHERE deleted_at IS NULL;""",
	]
	for sql in statements:
		if not _db.query(sql):
			push_error("Migration v2 failed: %s\nSQL: %s" % [_db.error_message, sql])
			return


func _migrate_to_v3() -> void:
	# Drop title column; journal entries are body-only.
	if not _journal_table_has_column("title"):
		return
	var statements: PackedStringArray = [
		"""CREATE TABLE journal_entries_v3 (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			body TEXT NOT NULL DEFAULT '',
			deleted_at INTEGER
		);""",
		"""INSERT INTO journal_entries_v3 (id, created_at, updated_at, body, deleted_at)
			SELECT id, created_at, updated_at,
				CASE
					WHEN trim(title) = '' THEN body
					WHEN trim(body) = '' THEN title
					ELSE title || char(10) || char(10) || body
				END,
				deleted_at
			FROM journal_entries;""",
		"DROP TABLE journal_entries;",
		"ALTER TABLE journal_entries_v3 RENAME TO journal_entries;",
		"""CREATE INDEX IF NOT EXISTS idx_journal_entries_active_created
			ON journal_entries (created_at DESC)
			WHERE deleted_at IS NULL;""",
	]
	for sql in statements:
		if not _db.query(sql):
			push_error("Migration v3 failed: %s\nSQL: %s" % [_db.error_message, sql])
			return


func _apply_default_settings() -> void:
	if get_setting(DbConstants.SETTING_UI_SCALE, "").is_empty():
		set_setting(DbConstants.SETTING_UI_SCALE, "1.0")
	if get_setting(DbConstants.SETTING_JOURNAL_SORT_NEWEST_FIRST, "").is_empty():
		set_setting(DbConstants.SETTING_JOURNAL_SORT_NEWEST_FIRST, "true")


# --- Settings ----------------------------------------------------------------

func get_setting(key: String, default_value: String = "") -> String:
	if not _db.query_with_bindings(
		"SELECT value FROM app_settings WHERE key = ?;",
		[key]
	):
		return default_value
	if _db.query_result.is_empty():
		return default_value
	return str(_db.query_result[0].get("value", default_value))


func set_setting(key: String, value: String) -> bool:
	return _db.query_with_bindings(
		"INSERT INTO app_settings (key, value) VALUES (?, ?)
		ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
		[key, value]
	)


# --- Journal -----------------------------------------------------------------

func count_journal_entries(include_deleted: bool = false) -> int:
	var where := "" if include_deleted else " WHERE deleted_at IS NULL"
	if not _db.query("SELECT COUNT(*) AS c FROM journal_entries%s;" % where):
		return 0
	return int(_db.query_result[0].get("c", 0))


func fetch_journal_entries(
	newest_first: bool,
	limit: int,
	offset: int,
	include_deleted: bool = false
) -> Array:
	var order := "DESC" if newest_first else "ASC"
	var where := "" if include_deleted else " WHERE deleted_at IS NULL"
	var sql := (
		"SELECT id, created_at, updated_at, body, deleted_at "
		+ "FROM journal_entries%s ORDER BY created_at %s LIMIT ? OFFSET ?;"
	) % [where, order]
	if not _db.query_with_bindings(sql, [limit, offset]):
		push_error("fetch_journal_entries: %s" % _db.error_message)
		return []
	return _db.query_result.duplicate(true)


func fetch_journal_entry_by_id(entry_id: int) -> Dictionary:
	if not _db.query_with_bindings(
		"SELECT id, created_at, updated_at, body, deleted_at "
		+ "FROM journal_entries WHERE id = ?;",
		[entry_id]
	):
		return {}
	if _db.query_result.is_empty():
		return {}
	return _db.query_result[0]


func search_journal_entries(query: String, limit: int = 50) -> Array:
	var pattern := "%" + query.strip_edges() + "%"
	if not _db.query_with_bindings(
		"SELECT id, created_at, updated_at, body, deleted_at "
		+ "FROM journal_entries WHERE deleted_at IS NULL "
		+ "AND body LIKE ? "
		+ "ORDER BY created_at DESC LIMIT ?;",
		[pattern, limit]
	):
		return []
	return _db.query_result.duplicate(true)


func insert_journal_entry(body: String) -> int:
	var now := int(Time.get_unix_time_from_system())
	if not _db.query_with_bindings(
		"INSERT INTO journal_entries (created_at, updated_at, body) "
		+ "VALUES (?, ?, ?);",
		[now, now, body]
	):
		push_error("insert_journal_entry: %s" % _db.error_message)
		return -1
	return int(_db.last_insert_rowid)


func update_journal_entry(entry: JournalEntry) -> bool:
	var now := int(Time.get_unix_time_from_system())
	return _db.query_with_bindings(
		"UPDATE journal_entries SET updated_at = ?, body = ? "
		+ "WHERE id = ? AND deleted_at IS NULL;",
		[now, entry.body, entry.id]
	)


func soft_delete_journal_entry(entry_id: int) -> bool:
	var now := int(Time.get_unix_time_from_system())
	return _db.query_with_bindings(
		"UPDATE journal_entries SET deleted_at = ?, updated_at = ? WHERE id = ?;",
		[now, now, entry_id]
	)


# --- Todos -------------------------------------------------------------------

func count_todos(include_deleted: bool = false) -> int:
	var where := "" if include_deleted else " WHERE deleted_at IS NULL"
	if not _db.query("SELECT COUNT(*) AS c FROM todos%s;" % where):
		return 0
	return int(_db.query_result[0].get("c", 0))


func fetch_todos(include_deleted: bool = false) -> Array:
	var where := "" if include_deleted else " WHERE deleted_at IS NULL"
	var sql := (
		"SELECT id, created_at, updated_at, title, notes, status, priority, "
		+ "due_at, sort_order, journal_entry_id, deleted_at FROM todos%s "
		+ "ORDER BY sort_order ASC, created_at DESC;"
	) % where
	if not _db.query(sql):
		push_error("fetch_todos: %s" % _db.error_message)
		return []
	return _db.query_result.duplicate(true)


func fetch_todo_by_id(todo_id: int) -> Dictionary:
	if not _db.query_with_bindings(
		"SELECT id, created_at, updated_at, title, notes, status, priority, "
		+ "due_at, sort_order, journal_entry_id, deleted_at FROM todos WHERE id = ?;",
		[todo_id]
	):
		return {}
	if _db.query_result.is_empty():
		return {}
	return _db.query_result[0]


func insert_todo(
	title: String,
	notes: String,
	status: String,
	priority: int,
	due_at: int,
	journal_entry_id: int,
	sort_order: int = -1
) -> int:
	var now := int(Time.get_unix_time_from_system())
	if sort_order < 0:
		sort_order = count_todos()
	var due_val: Variant = due_at if due_at > 0 else null
	var journal_val: Variant = journal_entry_id if journal_entry_id > 0 else null
	if not _db.query_with_bindings(
		"INSERT INTO todos (created_at, updated_at, title, notes, status, priority, "
		+ "due_at, sort_order, journal_entry_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);",
		[now, now, title, notes, status, priority, due_val, sort_order, journal_val]
	):
		push_error("insert_todo: %s" % _db.error_message)
		return -1
	return int(_db.last_insert_rowid)


func update_todo(item: TodoItem) -> bool:
	var now := int(Time.get_unix_time_from_system())
	var due_val: Variant = item.due_at if item.due_at > 0 else null
	var journal_val: Variant = item.journal_entry_id if item.journal_entry_id > 0 else null
	return _db.query_with_bindings(
		"UPDATE todos SET updated_at = ?, title = ?, notes = ?, status = ?, "
		+ "priority = ?, due_at = ?, sort_order = ?, journal_entry_id = ? "
		+ "WHERE id = ? AND deleted_at IS NULL;",
		[
			now,
			item.title,
			item.notes,
			item.status,
			item.priority,
			due_val,
			item.sort_order,
			journal_val,
			item.id,
		]
	)


func soft_delete_todo(todo_id: int) -> bool:
	var now := int(Time.get_unix_time_from_system())
	return _db.query_with_bindings(
		"UPDATE todos SET deleted_at = ?, updated_at = ? WHERE id = ?;",
		[now, now, todo_id]
	)


# --- Pomodoro (minimal persistence API) --------------------------------------

func insert_pomodoro_session(
	target_type: String,
	target_id: int,
	planned_duration_sec: int = PomodoroSession.DEFAULT_DURATION_SEC
) -> int:
	var now := int(Time.get_unix_time_from_system())
	var target_val: Variant = target_id if target_id > 0 else null
	if not _db.query_with_bindings(
		"INSERT INTO pomodoro_sessions "
		+ "(started_at, planned_duration_sec, target_type, target_id) "
		+ "VALUES (?, ?, ?, ?);",
		[now, planned_duration_sec, target_type, target_val]
	):
		push_error("insert_pomodoro_session: %s" % _db.error_message)
		return -1
	var session_id := int(_db.last_insert_rowid)
	if session_id <= 0:
		push_error("insert_pomodoro_session: invalid row id")
		return -1
	return session_id


func complete_pomodoro_session(session_id: int, completed: bool = true) -> bool:
	var now := int(Time.get_unix_time_from_system())
	return _db.query_with_bindings(
		"UPDATE pomodoro_sessions SET ended_at = ?, completed = ? WHERE id = ?;",
		[now, 1 if completed else 0, session_id]
	)


func update_pomodoro_session_target(session_id: int, target_id: int) -> bool:
	if session_id <= 0:
		return false
	var target_val: Variant = target_id if target_id > 0 else null
	return _db.query_with_bindings(
		"UPDATE pomodoro_sessions SET target_id = ? WHERE id = ?;",
		[target_val, session_id]
	)


func fetch_todo_pomodoro_work_stats_map() -> Dictionary:
	if not _db.query_with_bindings(
		"SELECT target_id, "
		+ "SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) AS completed_pomodoros, "
		+ "SUM(CASE WHEN ended_at IS NOT NULL AND ended_at > started_at "
		+ "THEN (ended_at - started_at) ELSE 0 END) AS total_work_sec "
		+ "FROM pomodoro_sessions WHERE target_type = ? AND target_id IS NOT NULL "
		+ "GROUP BY target_id;",
		[DbConstants.TARGET_TODO]
	):
		push_error("fetch_todo_pomodoro_work_stats_map: %s" % _db.error_message)
		return {}
	var result: Dictionary = {}
	for row in _db.query_result:
		var todo_id := int(row.get("target_id", 0))
		if todo_id <= 0:
			continue
		result[todo_id] = {
			"completed_pomodoros": int(row.get("completed_pomodoros", 0)),
			"total_work_sec": int(row.get("total_work_sec", 0)),
		}
	return result


func fetch_todo_pomodoro_work_stats(todo_id: int) -> Dictionary:
	if todo_id <= 0:
		return _empty_todo_work_stats()
	if not _db.query_with_bindings(
		"SELECT "
		+ "SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) AS completed_pomodoros, "
		+ "SUM(CASE WHEN ended_at IS NOT NULL AND ended_at > started_at "
		+ "THEN (ended_at - started_at) ELSE 0 END) AS total_work_sec "
		+ "FROM pomodoro_sessions WHERE target_type = ? AND target_id = ?;",
		[DbConstants.TARGET_TODO, todo_id]
	):
		return _empty_todo_work_stats()
	if _db.query_result.is_empty():
		return _empty_todo_work_stats()
	var row := _db.query_result[0]
	return {
		"completed_pomodoros": int(row.get("completed_pomodoros", 0)),
		"total_work_sec": int(row.get("total_work_sec", 0)),
	}


func _empty_todo_work_stats() -> Dictionary:
	return {"completed_pomodoros": 0, "total_work_sec": 0}
