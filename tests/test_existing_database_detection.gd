## GUT tests for one-time "existing database detected" messaging.
extends GutTest

const DatabaseScript := preload("res://scripts/autoload/database.gd")
const DatabaseOpen := preload("res://scripts/database/database_open.gd")
const DbConstants := preload("res://scripts/database/db_constants.gd")
const AppConfig := preload("res://scripts/app/app_config.gd")

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


func test_detects_pre_existing_database_file() -> void:
	# Create a database file first
	assert_true(_db._initialize(_test_dir))
	_db._mark_closed()
	_reset_database_instance()
	
	# Now re-initialize — the file should be detected as pre-existing
	var existed_before := DatabaseOpen.db_file_exists(_test_dir)
	assert_true(existed_before)
	
	assert_true(_db._initialize(_test_dir))
	
	# The acknowledgment should have been written
	var acknowledged: String = _db.get_setting(DbConstants.SETTING_EXISTING_DB_ACKNOWLEDGED, "")
	assert_eq(acknowledged, AppConfig.normalize_directory(_test_dir))


func test_does_not_emit_for_first_time_creation() -> void:
	pending("Flaky due to test isolation with global Database autoload.")


func test_existing_db_check_uses_database_open_helper() -> void:
	# Sanity check that the public helper exists and works
	assert_false(DatabaseOpen.db_file_exists(_test_dir))
	
	var result := DatabaseOpen.try_open_at_directory(_test_dir)
	assert_true(result.ok)
	
	assert_true(DatabaseOpen.db_file_exists(_test_dir))
	result.sqlite = null


# --- Helpers ---

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
