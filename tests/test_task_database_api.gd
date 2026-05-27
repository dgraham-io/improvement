## GUT regression: task CRUD and task-target pomodoro inserts on fresh schema.
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
	assert_true(_db._initialize(_test_dir))


func after_each() -> void:
	_db._db = null
	_db.is_ready = false
	await wait_process_frames(2)
	_remove_directory_recursive(_test_dir)


func test_insert_task_and_pomodoro_session() -> void:
	var task_id: int = _db.insert_task("API task", "", DbConstants.TASK_PENDING, 0, 0, 0)
	assert_gt(task_id, 0)
	var session_id: int = _db.insert_pomodoro_session(DbConstants.TARGET_TASK, task_id)
	assert_gt(session_id, 0)


func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_task_api_%d" % Time.get_ticks_usec()
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
