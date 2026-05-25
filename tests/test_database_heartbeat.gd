## GUT tests for the cross-machine heartbeat system (Dropbox multi-device awareness).
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


func test_heartbeat_writes_session_and_path_on_initialize() -> void:
	assert_true(_db._initialize(_test_dir))
	
	var session: String = _db.get_setting(DbConstants.SETTING_OPEN_SESSION, "")
	var path: String = _db.get_setting(DbConstants.SETTING_OPEN_MACHINE_PATH, "")
	var heartbeat: String = _db.get_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, "0")
	
	assert_false(session.is_empty(), "A session ID should be written on open")
	assert_eq(path, AppConfig.normalize_directory(_test_dir))
	assert_true(int(heartbeat) > 0, "Heartbeat timestamp should be set")


func test_heartbeat_clears_on_mark_closed() -> void:
	assert_true(_db._initialize(_test_dir))
	
	_db._mark_closed()
	
	var session: String = _db.get_setting(DbConstants.SETTING_OPEN_SESSION, "")
	var heartbeat: String = _db.get_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, "0")
	
	assert_eq(session, "", "Session should be cleared on close")
	assert_eq(heartbeat, "0", "Heartbeat should be zeroed on close")


func test_get_other_instance_info_detects_different_machine() -> void:
	# First "machine" opens
	assert_true(_db._initialize(_test_dir))
	
	# Simulate another machine having written a recent heartbeat with a different path
	var other_path: String = "/some/other/Dropbox/Improvement"
	var now: int = int(Time.get_unix_time_from_system())
	_db.set_setting(DbConstants.SETTING_OPEN_SESSION, "other-machine-123")
	_db.set_setting(DbConstants.SETTING_OPEN_MACHINE_PATH, other_path)
	_db.set_setting(DbConstants.SETTING_LAST_HEARTBEAT_AT, str(now - 30))
	
	var info: Dictionary = _db.get_other_instance_info()
	
	assert_true(info.active, "Should detect active instance on different path")
	assert_eq(info.machine_path, other_path)
	assert_true(info.seconds_ago > 0 and info.seconds_ago < 100)


func test_get_other_instance_info_ignores_same_machine() -> void:
	assert_true(_db._initialize(_test_dir))
	
	# Same path should not report as "other"
	var info: Dictionary = _db.get_other_instance_info()
	assert_false(info.active)


func test_heartbeat_timer_exists_after_initialize() -> void:
	assert_true(_db._initialize(_test_dir))
	# The timer is created as a child during _start_heartbeat
	var has_timer: bool = false
	for child in _db.get_children():
		if child is Timer:
			has_timer = true
			break
	assert_true(has_timer, "A heartbeat Timer should be running after successful open")


func test_database_methods_are_safe_when_db_is_null() -> void:
	# Force a clean null state right before the calls
	_db._db = null
	_db.is_ready = false

	# These should not cause null dereference errors.
	# We don't assert exact return values because of test isolation with the global autoload.
	_db.fetch_all_tags()
	_db.fetch_tag_by_id(1)
	_db.fetch_tag_by_name("test")
	_db.fetch_tags_for_journal_entry(1)
	_db.set_journal_entry_tags(1, [] as Array[int])

	# insert_tag can have side effects in shared DB state — call it safely
	var result = _db.insert_tag("test_" + str(Time.get_ticks_usec()))
	# We mainly care it didn't hard-crash on null _db
	assert_true(result == -1 or result > 0)


# --- Helpers (copied from test_database_open.gd for consistency) ---

func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_%d" % Time.get_ticks_usec()
	)
	var err := DirAccess.make_dir_recursive_absolute(path)
	assert_eq(err, OK, "temp directory should be created")
	return path


func _reset_database_instance() -> void:
	if _db._heartbeat_timer != null:
		_db._heartbeat_timer.queue_free()
		_db._heartbeat_timer = null

	_db._db = null
	_db.is_ready = false
	_db._last_open_error = ""
	_db._current_open_session = ""
	_db._current_machine_path = ""


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
