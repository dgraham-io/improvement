## Autoload: opens `<db_directory>/improvement.db`, runs migrations, exposes typed data access.
## UI and feature code should use JournalService / TaskService, not query SQL directly.
extends Node

const _DatabaseOpen := preload("res://scripts/database/database_open.gd")
const _DailyWorkStats := preload("res://scripts/models/daily_work_stats.gd")
const _Tag := preload("res://scripts/models/tag.gd")
const _TagNames := preload("res://scripts/tags/tag_names.gd")

signal ready_changed(is_ready: bool)
signal other_instance_detected(machine_path: String, last_heartbeat_at: int)
signal existing_database_detected(db_path: String)

var is_ready: bool = false

var _db: SQLite
var _last_open_error: String = ""

# Heartbeat state for cross-machine "another instance may be open" detection (Dropbox use case)
var _heartbeat_timer: Timer
var _current_open_session: String = ""
var _current_machine_path: String = ""


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

	_start_heartbeat(db_directory)
	_check_for_other_instance(db_directory)
	_check_for_existing_database(db_directory)
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
		version = 3
	if version < 4:
		_migrate_to_v4()
		_set_user_version(4)
		version = 4
	if version < 5:
		_migrate_to_v5()
		_set_user_version(5)
		version = 5
	if version < 6:
		_migrate_to_v6()
		_set_user_version(6)


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
		"""CREATE TABLE IF NOT EXISTS tasks (
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
		"""CREATE INDEX IF NOT EXISTS idx_tasks_active_sort
			ON tasks (sort_order ASC, created_at DESC)
			WHERE deleted_at IS NULL;""",
		"""CREATE INDEX IF NOT EXISTS idx_tasks_active_due
			ON tasks (due_at ASC)
			WHERE deleted_at IS NULL AND due_at IS NOT NULL;""",
		"""CREATE TABLE IF NOT EXISTS pomodoro_sessions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			started_at INTEGER NOT NULL,
			ended_at INTEGER,
			planned_duration_sec INTEGER NOT NULL DEFAULT 1500,
			target_type TEXT NOT NULL DEFAULT 'none'
				CHECK (target_type IN ('none', 'journal', 'task')),
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


func _migrate_to_v4() -> void:
	var statements: PackedStringArray = [
		"""CREATE TABLE IF NOT EXISTS tags (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL COLLATE NOCASE,
			created_at INTEGER NOT NULL,
			UNIQUE (name)
		);""",
		"""CREATE TABLE IF NOT EXISTS journal_entry_tags (
			entry_id INTEGER NOT NULL REFERENCES journal_entries (id) ON DELETE CASCADE,
			tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
			PRIMARY KEY (entry_id, tag_id)
		);""",
		"""CREATE TABLE IF NOT EXISTS task_tags (
			task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
			tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
			PRIMARY KEY (task_id, tag_id)
		);""",
		"""CREATE INDEX IF NOT EXISTS idx_journal_entry_tags_tag
			ON journal_entry_tags (tag_id);""",
		"""CREATE INDEX IF NOT EXISTS idx_task_tags_tag
			ON task_tags (tag_id);""",
	]
	for sql in statements:
		if not _db.query(sql):
			push_error("Migration v4 failed: %s\nSQL: %s" % [_db.error_message, sql])
			return


func _table_exists(table_name: String) -> bool:
	if _db == null:
		return false
	if not _db.query_with_bindings(
		"SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1;",
		[table_name]
	):
		return false
	return not _db.query_result.is_empty()


func _migrate_to_v5() -> void:
	# Rename todo terminology → task terminology.
	# This migration is safe to run on fresh DBs (created as v1 then upgraded)
	# and on existing DBs that already have v4 tags.
	if _table_exists("todos") and not _table_exists("tasks"):
		if not _db.query("ALTER TABLE todos RENAME TO tasks;"):
			push_error("Migration v5 failed: %s\nSQL: %s" % [_db.error_message, "ALTER TABLE todos RENAME TO tasks;"])
			return

	# Rebuild todo_tags → task_tags so the FK references tasks.
	if _table_exists("todo_tags") and not _table_exists("task_tags"):
		var statements: PackedStringArray = [
			"""CREATE TABLE IF NOT EXISTS task_tags (
				task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
				tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
				PRIMARY KEY (task_id, tag_id)
			);""",
			"INSERT OR IGNORE INTO task_tags (task_id, tag_id) SELECT todo_id, tag_id FROM todo_tags;",
			"DROP TABLE todo_tags;",
			"DROP INDEX IF EXISTS idx_todo_tags_tag;",
			"""CREATE INDEX IF NOT EXISTS idx_task_tags_tag
				ON task_tags (tag_id);""",
		]
		for sql in statements:
			if not _db.query(sql):
				push_error("Migration v5 failed: %s\nSQL: %s" % [_db.error_message, sql])
				return
	elif _table_exists("task_tags"):
		# Ensure index name exists for new table.
		_db.query("CREATE INDEX IF NOT EXISTS idx_task_tags_tag ON task_tags (tag_id);")

	# Rename indexes for clarity (not required for correctness).
	_db.query("DROP INDEX IF EXISTS idx_todos_active_sort;")
	_db.query("DROP INDEX IF EXISTS idx_todos_active_due;")
	_db.query(
		"CREATE INDEX IF NOT EXISTS idx_tasks_active_sort "
		+ "ON tasks (sort_order ASC, created_at DESC) WHERE deleted_at IS NULL;"
	)
	_db.query(
		"CREATE INDEX IF NOT EXISTS idx_tasks_active_due "
		+ "ON tasks (due_at ASC) WHERE deleted_at IS NULL AND due_at IS NOT NULL;"
	)


func _migrate_to_v6() -> void:
	# Update legacy pomodoro target types: 'todo' → 'task'.
	# Old DBs enforced CHECK(target_type IN ('none','journal','todo')), which blocks starting task pomodoros.
	if not _table_exists("pomodoro_sessions"):
		return
	if not _db.query("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'pomodoro_sessions' LIMIT 1;"):
		return
	if _db.query_result.is_empty():
		return
	var create_sql := str(_db.query_result[0].get("sql", ""))
	if create_sql.is_empty():
		return
	# Only rebuild if this DB still references the legacy 'todo' value.
	if create_sql.find("'todo'") == -1:
		# Still normalize any stored rows just in case (cheap, safe).
		_db.query("UPDATE pomodoro_sessions SET target_type = 'task' WHERE target_type = 'todo';")
		return

	var statements: PackedStringArray = [
		"""CREATE TABLE pomodoro_sessions_v6 (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			started_at INTEGER NOT NULL,
			ended_at INTEGER,
			planned_duration_sec INTEGER NOT NULL DEFAULT 1500,
			target_type TEXT NOT NULL DEFAULT 'none'
				CHECK (target_type IN ('none', 'journal', 'task')),
			target_id INTEGER,
			completed INTEGER NOT NULL DEFAULT 0
				CHECK (completed IN (0, 1))
		);""",
		"""INSERT INTO pomodoro_sessions_v6
			(id, started_at, ended_at, planned_duration_sec, target_type, target_id, completed)
			SELECT
				id,
				started_at,
				ended_at,
				planned_duration_sec,
				CASE WHEN target_type = 'todo' THEN 'task' ELSE target_type END,
				target_id,
				completed
			FROM pomodoro_sessions;""",
		"DROP TABLE pomodoro_sessions;",
		"ALTER TABLE pomodoro_sessions_v6 RENAME TO pomodoro_sessions;",
		"DROP INDEX IF EXISTS idx_pomodoro_started;",
		"CREATE INDEX IF NOT EXISTS idx_pomodoro_started ON pomodoro_sessions (started_at DESC);",
	]
	for sql in statements:
		if not _db.query(sql):
			push_error("Migration v6 failed: %s\nSQL: %s" % [_db.error_message, sql])
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
	include_deleted: bool = false,
	filter_tag_ids: Array = []
) -> Array:
	var order := "DESC" if newest_first else "ASC"
	var where_parts: PackedStringArray = []
	if not include_deleted:
		where_parts.append("je.deleted_at IS NULL")
	var bindings: Array = []
	if not filter_tag_ids.is_empty():
		var placeholders: PackedStringArray = []
		for tag_id in filter_tag_ids:
			var id := int(tag_id)
			if id <= 0:
				continue
			placeholders.append("?")
			bindings.append(id)
		if not placeholders.is_empty():
			where_parts.append(
				"je.id IN (SELECT entry_id FROM journal_entry_tags WHERE tag_id IN (%s))"
				% ",".join(placeholders)
			)
	var where := ""
	if not where_parts.is_empty():
		where = " WHERE " + " AND ".join(where_parts)
	var sql := (
		"SELECT je.id, je.created_at, je.updated_at, je.body, je.deleted_at "
		+ "FROM journal_entries je%s ORDER BY je.created_at %s LIMIT ? OFFSET ?;"
	) % [where, order]
	bindings.append(limit)
	bindings.append(offset)
	if not _db.query_with_bindings(sql, bindings):
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


# --- Tasks -------------------------------------------------------------------

func count_todos(include_deleted: bool = false) -> int:
	var where := "" if include_deleted else " WHERE deleted_at IS NULL"
	if not _db.query("SELECT COUNT(*) AS c FROM tasks%s;" % where):
		return 0
	return int(_db.query_result[0].get("c", 0))


func fetch_todos(include_deleted: bool = false, filter_tag_ids: Array = []) -> Array:
	var where_parts: PackedStringArray = []
	if not include_deleted:
		where_parts.append("t.deleted_at IS NULL")
	var bindings: Array = []
	if not filter_tag_ids.is_empty():
		var placeholders: PackedStringArray = []
		for tag_id in filter_tag_ids:
			var id := int(tag_id)
			if id <= 0:
				continue
			placeholders.append("?")
			bindings.append(id)
		if not placeholders.is_empty():
			where_parts.append(
				"t.id IN (SELECT task_id FROM task_tags WHERE tag_id IN (%s))"
				% ",".join(placeholders)
			)
	var where := ""
	if not where_parts.is_empty():
		where = " WHERE " + " AND ".join(where_parts)
	var sql := (
		"SELECT t.id, t.created_at, t.updated_at, t.title, t.notes, t.status, t.priority, "
		+ "t.due_at, t.sort_order, t.journal_entry_id, t.deleted_at FROM tasks t%s "
		+ "ORDER BY CASE WHEN t.status = 'done' THEN 1 ELSE 0 END, "
		+ "t.sort_order ASC, t.created_at DESC;"
	) % where
	if bindings.is_empty():
		if not _db.query(sql):
			push_error("fetch_todos: %s" % _db.error_message)
			return []
	else:
		if not _db.query_with_bindings(sql, bindings):
			push_error("fetch_todos: %s" % _db.error_message)
			return []
	return _db.query_result.duplicate(true)


func fetch_todo_by_id(todo_id: int) -> Dictionary:
	if not _db.query_with_bindings(
		"SELECT id, created_at, updated_at, title, notes, status, priority, "
		+ "due_at, sort_order, journal_entry_id, deleted_at FROM tasks WHERE id = ?;",
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
		"INSERT INTO tasks (created_at, updated_at, title, notes, status, priority, "
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
		"UPDATE tasks SET updated_at = ?, title = ?, notes = ?, status = ?, "
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


func set_todo_updated_at(todo_id: int, updated_at: int) -> bool:
	return _db.query_with_bindings(
		"UPDATE tasks SET updated_at = ? WHERE id = ? AND deleted_at IS NULL;",
		[updated_at, todo_id]
	)


func soft_delete_todo(todo_id: int) -> bool:
	var now := int(Time.get_unix_time_from_system())
	return _db.query_with_bindings(
		"UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?;",
		[now, now, todo_id]
	)


## Soft-deletes done missions with updated_at strictly before [param cutoff_unix]. Returns affected ids.
func soft_delete_done_todos_before(cutoff_unix: int) -> Array[int]:
	if cutoff_unix <= 0:
		return []
	if not _db.query_with_bindings(
		"SELECT id FROM tasks WHERE deleted_at IS NULL AND status = ? AND updated_at < ?;",
		[DbConstants.TASK_DONE, cutoff_unix]
	):
		push_error("soft_delete_done_todos_before select: %s" % _db.error_message)
		return []
	var ids: Array[int] = []
	for row in _db.query_result:
		ids.append(int(row.get("id", 0)))
	if ids.is_empty():
		return []
	var now := int(Time.get_unix_time_from_system())
	for todo_id in ids:
		if not _db.query_with_bindings(
			"UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL;",
			[now, now, todo_id]
		):
			push_error("soft_delete_done_todos_before: %s" % _db.error_message)
	return ids


# --- Tags --------------------------------------------------------------------

func fetch_all_tags() -> Array:
	if _db == null:
		return []
	if not _db.query(
		"SELECT id, name, created_at FROM tags ORDER BY name COLLATE NOCASE ASC;"
	):
		push_error("fetch_all_tags: %s" % _db.error_message)
		return []
	return _db.query_result.duplicate(true)


func fetch_tag_by_id(tag_id: int) -> Dictionary:
	if _db == null:
		return {}
	if not _db.query_with_bindings(
		"SELECT id, name, created_at FROM tags WHERE id = ?;",
		[tag_id]
	):
		return {}
	if _db.query_result.is_empty():
		return {}
	return _db.query_result[0]


func fetch_tag_by_name(name: String) -> Dictionary:
	if _db == null:
		return {}
	var normalized := _TagNames.normalize(name)
	if normalized.is_empty():
		return {}
	if not _db.query_with_bindings(
		"SELECT id, name, created_at FROM tags WHERE name = ? COLLATE NOCASE;",
		[normalized]
	):
		return {}
	if _db.query_result.is_empty():
		return {}
	return _db.query_result[0]


func insert_tag(name: String) -> int:
	if _db == null:
		return -1
	var normalized := _TagNames.normalize(name)
	if normalized.is_empty():
		return -1
	var now := int(Time.get_unix_time_from_system())
	if not _db.query_with_bindings(
		"INSERT INTO tags (name, created_at) VALUES (?, ?);",
		[normalized, now]
	):
		push_error("insert_tag: %s" % _db.error_message)
		return -1
	return int(_db.last_insert_rowid)


func fetch_tags_for_journal_entry(entry_id: int) -> Array:
	if _db == null or entry_id <= 0:
		return []
	if not _db.query_with_bindings(
		"SELECT t.id, t.name, t.created_at "
		+ "FROM journal_entry_tags jet "
		+ "JOIN tags t ON t.id = jet.tag_id "
		+ "WHERE jet.entry_id = ? "
		+ "ORDER BY t.name COLLATE NOCASE ASC;",
		[entry_id]
	):
		push_error("fetch_tags_for_journal_entry: %s" % _db.error_message)
		return []
	return _db.query_result.duplicate(true)


func fetch_tags_for_todo(todo_id: int) -> Array:
	if _db == null or todo_id <= 0:
		return []
	if not _db.query_with_bindings(
		"SELECT t.id, t.name, t.created_at "
		+ "FROM task_tags tt "
		+ "JOIN tags t ON t.id = tt.tag_id "
		+ "WHERE tt.task_id = ? "
		+ "ORDER BY t.name COLLATE NOCASE ASC;",
		[todo_id]
	):
		push_error("fetch_tags_for_todo: %s" % _db.error_message)
		return []
	return _db.query_result.duplicate(true)


func fetch_journal_entry_tags_map() -> Dictionary:
	if _db == null:
		return {}
	if not _db.query(
		"SELECT jet.entry_id, t.id, t.name, t.created_at "
		+ "FROM journal_entry_tags jet "
		+ "JOIN tags t ON t.id = jet.tag_id "
		+ "ORDER BY t.name COLLATE NOCASE ASC;"
	):
		push_error("fetch_journal_entry_tags_map: %s" % _db.error_message)
		return {}
	return _build_entity_tags_map("entry_id")


func fetch_todo_tags_map() -> Dictionary:
	if _db == null:
		return {}
	if not _db.query(
		"SELECT tt.task_id, t.id, t.name, t.created_at "
		+ "FROM task_tags tt "
		+ "JOIN tags t ON t.id = tt.tag_id "
		+ "ORDER BY t.name COLLATE NOCASE ASC;"
	):
		push_error("fetch_todo_tags_map: %s" % _db.error_message)
		return {}
	return _build_entity_tags_map("task_id")


func _build_entity_tags_map(entity_key: String) -> Dictionary:
	var result: Dictionary = {}
	for row in _db.query_result:
		var entity_id := int(row.get(entity_key, 0))
		if entity_id <= 0:
			continue
		if not result.has(entity_id):
			result[entity_id] = []
		result[entity_id].append(_Tag.from_row(row))
	return result


func set_journal_entry_tags(entry_id: int, tag_ids: Array[int]) -> bool:
	if _db == null or entry_id <= 0:
		return false
	if not _db.query_with_bindings(
		"DELETE FROM journal_entry_tags WHERE entry_id = ?;",
		[entry_id]
	):
		push_error("set_journal_entry_tags delete: %s" % _db.error_message)
		return false
	for tag_id in tag_ids:
		if tag_id <= 0:
			continue
		if not _db.query_with_bindings(
			"INSERT INTO journal_entry_tags (entry_id, tag_id) VALUES (?, ?);",
			[entry_id, tag_id]
		):
			push_error("set_journal_entry_tags insert: %s" % _db.error_message)
			return false
	return true


func set_todo_tags(todo_id: int, tag_ids: Array[int]) -> bool:
	if _db == null or todo_id <= 0:
		return false
	if not _db.query_with_bindings(
		"DELETE FROM task_tags WHERE task_id = ?;",
		[todo_id]
	):
		push_error("set_todo_tags delete: %s" % _db.error_message)
		return false
	for tag_id in tag_ids:
		if tag_id <= 0:
			continue
		if not _db.query_with_bindings(
			"INSERT INTO task_tags (task_id, tag_id) VALUES (?, ?);",
			[todo_id, tag_id]
		):
			push_error("set_todo_tags insert: %s" % _db.error_message)
			return false
	return true


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
		[DbConstants.TARGET_TASK]
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
		[DbConstants.TARGET_TASK, todo_id]
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


func fetch_daily_pomodoro_stats(day_anchor_unix: int) -> Dictionary:
	if day_anchor_unix <= 0:
		return _empty_daily_work_stats()
	var summary := _empty_daily_work_stats()
	var day_end_unix := day_anchor_unix + 86400
	if not _db.query_with_bindings(
		"SELECT COUNT(*) AS session_count, "
		+ "SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) AS completed_pomodoros, "
		+ "SUM(CASE WHEN ended_at IS NOT NULL AND ended_at > started_at "
		+ "THEN (ended_at - started_at) ELSE 0 END) AS total_work_sec, "
		+ "SUM(CASE WHEN target_type = ? AND ended_at IS NOT NULL AND ended_at > started_at "
		+ "THEN (ended_at - started_at) ELSE 0 END) AS journal_work_sec, "
		+ "SUM(CASE WHEN target_type = ? AND ended_at IS NOT NULL AND ended_at > started_at "
		+ "THEN (ended_at - started_at) ELSE 0 END) AS task_work_sec "
		+ "FROM pomodoro_sessions "
		+ "WHERE started_at >= ? AND started_at < ?;",
		[DbConstants.TARGET_JOURNAL, DbConstants.TARGET_TASK, day_anchor_unix, day_end_unix]
	):
		push_error("fetch_daily_pomodoro_stats: %s" % _db.error_message)
		return summary
	if not _db.query_result.is_empty():
		var row := _db.query_result[0]
		summary["session_count"] = DbRow.int_value(row.get("session_count"))
		summary["completed_pomodoros"] = DbRow.int_value(row.get("completed_pomodoros"))
		summary["total_work_sec"] = DbRow.int_value(row.get("total_work_sec"))
		summary["journal_work_sec"] = DbRow.int_value(row.get("journal_work_sec"))
		summary["todo_work_sec"] = DbRow.int_value(row.get("task_work_sec"))
	summary["hourly_work_sec"] = _fetch_daily_hourly_work_sec(day_anchor_unix)
	return summary


func _fetch_daily_hourly_work_sec(day_anchor_unix: int) -> PackedInt32Array:
	var hourly := PackedInt32Array()
	hourly.resize(24)
	hourly.fill(0)
	var day_end_unix := day_anchor_unix + 86400
	if not _db.query_with_bindings(
		"SELECT CAST(strftime('%H', started_at, 'unixepoch', 'localtime') AS INTEGER) AS hour_of_day, "
		+ "SUM(CASE WHEN ended_at IS NOT NULL AND ended_at > started_at "
		+ "THEN (ended_at - started_at) ELSE 0 END) AS work_sec "
		+ "FROM pomodoro_sessions "
		+ "WHERE started_at >= ? AND started_at < ? "
		+ "GROUP BY hour_of_day;",
		[day_anchor_unix, day_end_unix]
	):
		push_error("_fetch_daily_hourly_work_sec: %s" % _db.error_message)
		return hourly
	for row in _db.query_result:
		var hour := DbRow.int_value(row.get("hour_of_day"), -1)
		if hour < 0 or hour > 23:
			continue
		hourly[hour] = DbRow.int_value(row.get("work_sec"))
	return hourly


func _empty_daily_work_stats() -> Dictionary:
	var empty: Dictionary = _DailyWorkStats.EMPTY.duplicate(true)
	var hourly := PackedInt32Array()
	hourly.resize(24)
	hourly.fill(0)
	empty["hourly_work_sec"] = hourly
	return empty


# --- Cross-machine heartbeat (Dropbox / shared-folder "another instance open" detection) ---

func _start_heartbeat(db_directory: String) -> void:
	_current_machine_path = AppConfig.normalize_directory(db_directory)
	_current_open_session = _generate_session_id()

	var now := int(Time.get_unix_time_from_system())
	_write_heartbeat(_current_open_session, _current_machine_path, now)

	# Start periodic timer (lightweight — only bumps the timestamp)
	if _heartbeat_timer != null:
		_heartbeat_timer.queue_free()

	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = 45.0
	_heartbeat_timer.autostart = true
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(_heartbeat_timer)

	# Also mark closed early on window close request (in addition to _exit_tree)
	var root := get_tree().root
	if root:
		var win := root as Window
		if win and not win.close_requested.is_connected(_on_close_requested):
			win.close_requested.connect(_on_close_requested)


func _generate_session_id() -> String:
	# Simple unique-per-run id, good enough for personal single-user detection
	return str(Time.get_unix_time_from_system()) + "_" + str(randi() % 100000)


func _write_heartbeat(session: String, machine_path: String, timestamp: int) -> void:
	set_setting(DbConstants.SETTING_OPEN_SESSION, session)
	set_setting(DbConstants.SETTING_OPEN_MACHINE_PATH, machine_path)
	set_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, str(timestamp))


func _on_heartbeat_tick() -> void:
	if _current_open_session.is_empty() or _current_machine_path.is_empty():
		return

	# Re-assert our ownership + fresh timestamp.
	# If another machine has taken over the session, we simply stop fighting.
	var current := get_setting(DbConstants.SETTING_OPEN_SESSION, "")
	if current != _current_open_session:
		# Another instance (possibly on this or another machine) has opened since we started.
		# Our heartbeat is no longer authoritative.
		return

	var now := int(Time.get_unix_time_from_system())
	set_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, str(now))


func _mark_closed() -> void:
	# Called on clean shutdown so the next machine to open sees a stale/closed state quickly.
	if _heartbeat_timer != null:
		_heartbeat_timer.stop()
		_heartbeat_timer = null

	_current_open_session = ""

	if _db != null:
		set_setting(DbConstants.SETTING_OPEN_SESSION, "")
		set_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, "0")


func _on_close_requested() -> void:
	_mark_closed()


func _check_for_other_instance(current_directory: String) -> void:
	var current_path := AppConfig.normalize_directory(current_directory)
	var prev_session := get_setting(DbConstants.SETTING_OPEN_SESSION, "")
	var prev_path := get_setting(DbConstants.SETTING_OPEN_MACHINE_PATH, "")
	var prev_ts_str := get_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, "0")
	var prev_ts := int(prev_ts_str) if prev_ts_str.is_valid_int() else 0

	if prev_session.is_empty():
		return
	if prev_path == current_path:
		return  # Same machine / same normalized path — normal reopen

	var now := int(Time.get_unix_time_from_system())
	if prev_ts <= 0:
		return

	var age := now - prev_ts
	if age > 0 and age < DbConstants.OTHER_INSTANCE_RECENT_SEC:
		push_warning("Database was recently opened on another computer (path: %s, %d seconds ago)." % [prev_path, age])
		other_instance_detected.emit(prev_path, prev_ts)


## Returns information about a possible open instance on another computer.
## Keys:
##   "active": bool                 — true if another machine path has a recent heartbeat
##   "machine_path": String
##   "last_heartbeat_at": int
##   "seconds_ago": int
##   "session": String
func get_other_instance_info() -> Dictionary:
	var session := get_setting(DbConstants.SETTING_OPEN_SESSION, "")
	var path := get_setting(DbConstants.SETTING_OPEN_MACHINE_PATH, "")
	var ts_str := get_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, "0")
	var ts := int(ts_str) if ts_str.is_valid_int() else 0

	var now := int(Time.get_unix_time_from_system())
	var age := now - ts if ts > 0 else 999999

	var our_path := _current_machine_path
	if our_path.is_empty():
		our_path = get_setting(DbConstants.SETTING_DB_DIRECTORY, "")

	var active := false
	if not session.is_empty() and path != our_path and ts > 0 and age >= 0 and age < DbConstants.OTHER_INSTANCE_RECENT_SEC:
		active = true

	return {
		"active": active,
		"machine_path": path,
		"last_heartbeat_at": ts,
		"seconds_ago": age if age < 999999 else -1,
		"session": session,
	}


func _check_for_existing_database(db_directory: String) -> void:
	if not _DatabaseOpen.db_file_exists(db_directory):
		return

	var current_path := AppConfig.normalize_directory(db_directory)
	var acknowledged := get_setting(DbConstants.SETTING_EXISTING_DB_ACKNOWLEDGED, "")

	# Only notify the first time we open an existing DB on this machine
	if acknowledged != current_path:
		set_setting(DbConstants.SETTING_EXISTING_DB_ACKNOWLEDGED, current_path)
		existing_database_detected.emit(current_path)


func _exit_tree() -> void:
	_mark_closed()
