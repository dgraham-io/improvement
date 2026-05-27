## GUT tests for Database open failure handling and recovery messages.
extends GutTest

const DatabaseScript := preload("res://scripts/autoload/database.gd")
const DatabaseOpen := preload("res://scripts/database/database_open.gd")


var _db: Node
var _test_dir: String = ""


func before_each() -> void:
	_test_dir = _make_temp_directory()
	_db = DatabaseScript.new()
	_reset_database_instance()
	add_child_autofree(_db)


func after_each() -> void:
	_reset_database_instance()
	await wait_process_frames(2)
	_remove_directory_recursive(_test_dir)


func test_format_open_error_locked() -> void:
	var directory := "C:/tmp/Improvement"
	var message := DatabaseOpen.format_open_error(directory, "database is locked")
	assert_string_contains(message, "in use")
	assert_string_contains(message, "improvement.db")


func test_format_open_error_busy() -> void:
	var message := DatabaseOpen.format_open_error(_test_dir, "database busy")
	assert_string_contains(message, "in use")


func test_format_open_error_readonly() -> void:
	var message := DatabaseOpen.format_open_error(
		_test_dir, "attempt to write a readonly database"
	)
	assert_string_contains(message, "read-only")


func test_format_open_error_includes_sqlite_message() -> void:
	var message := DatabaseOpen.format_open_error(_test_dir, "unable to open database file")
	assert_string_contains(message, "unable to open database file")
	assert_string_contains(message, "improvement.db")


func test_try_open_rejects_empty_path() -> void:
	var result := DatabaseOpen.try_open_at_directory("   ")
	assert_false(result.ok)
	assert_eq(result.error_message, "No database folder was selected.")


func test_try_open_creates_database_file() -> void:
	var result := DatabaseOpen.try_open_at_directory(_test_dir)
	assert_true(result.ok)
	assert_not_null(result.sqlite)
	var db_path := AppConfig.db_base_path(_test_dir) + ".db"
	assert_file_exists(db_path)
	result.sqlite = null


func test_try_open_fails_when_path_is_a_file() -> void:
	var blocker := _test_dir.path_join("blocker")
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	assert_not_null(file, "fixture file should be writable")
	file.store_string("x")
	file.close()

	var result := DatabaseOpen.try_open_at_directory(blocker)
	assert_false(result.ok)
	assert_false(result.error_message.is_empty())
	assert_engine_error("unable to open database file")


func test_database_open_at_directory_delegates_to_helper() -> void:
	assert_true(_db._open_at_directory(_test_dir))
	assert_not_null(_db._db)
	assert_true(_db._last_open_error.is_empty())


func test_initialize_emits_ready_changed_on_success() -> void:
	watch_signals(_db)
	assert_true(_db._initialize(_test_dir))
	assert_true(_db.is_ready)
	assert_eq(get_signal_emit_count(_db, "ready_changed"), 1)
	assert_eq(get_signal_parameters(_db, "ready_changed")[0], true)


func test_initialize_persists_db_directory_setting() -> void:
	assert_true(_db._initialize(_test_dir))
	var stored := AppConfig.normalize_directory(
		_db.get_setting(DbConstants.SETTING_DB_DIRECTORY, "")
	)
	assert_eq(stored, AppConfig.normalize_directory(_test_dir))


func test_get_last_error_on_failed_insert_tag() -> void:
	assert_true(_db._initialize(_test_dir))
	var tag_id: int = _db.insert_tag("   ")
	assert_eq(tag_id, -1)
	assert_string_contains(_db.get_last_error(), "insert_tag")


func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_%d" % Time.get_ticks_usec()
	)
	var err := DirAccess.make_dir_recursive_absolute(path)
	assert_eq(err, OK, "temp directory should be created")
	return path


func _reset_database_instance() -> void:
	_db._db = null
	_db.is_ready = false
	_db._last_open_error = ""


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
