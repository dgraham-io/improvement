## GUT tests for end-of-day task cleanup helpers.
extends GutTest

const DatabaseScript := preload("res://scripts/autoload/database.gd")
const TaskDayCleanup := preload("res://scripts/tasks/task_day_cleanup.gd")
const TimeFmt := preload("res://scripts/util/time_format.gd")

var _database: Node
var _test_dir: String = ""


func before_each() -> void:
	_test_dir = _make_temp_directory()
	_database = DatabaseScript.new()
	_database._db = null
	_database.is_ready = false
	add_child_autofree(_database)
	assert_true(_database._initialize(_test_dir))


func after_each() -> void:
	_database._db = null
	_database.is_ready = false
	await wait_process_frames(2)
	_remove_directory_recursive(_test_dir)


func test_should_run_cleanup_once_per_day() -> void:
	var now := int(Time.get_unix_time_from_system())
	var today := TaskDayCleanup.today_day_key(now)
	assert_true(TaskDayCleanup.should_run_cleanup("", now))
	assert_false(TaskDayCleanup.should_run_cleanup(today, now))


func test_ids_to_purge_only_done_before_today() -> void:
	var now := int(Time.get_unix_time_from_system())
	var today_start := TimeFmt.local_day_start(now)
	var yesterday := today_start - 3600
	var fresh_done := TaskItem.new()
	fresh_done.id = 1
	fresh_done.status = DbConstants.TASK_DONE
	fresh_done.updated_at = now
	var stale_done := TaskItem.new()
	stale_done.id = 2
	stale_done.status = DbConstants.TASK_DONE
	stale_done.updated_at = yesterday
	var active := TaskItem.new()
	active.id = 3
	active.status = DbConstants.TASK_PENDING
	active.updated_at = yesterday
	var ids := TaskDayCleanup.ids_to_purge([fresh_done, stale_done, active], today_start)
	assert_eq(ids.size(), 1)
	assert_eq(ids[0], 2)


func test_soft_delete_done_tasks_before() -> void:
	var now := int(Time.get_unix_time_from_system())
	var today_start := TimeFmt.local_day_start(now)
	var yesterday := today_start - 3600
	var keep_id: int = _database.insert_task("Keep", "", DbConstants.TASK_DONE, 0, 0, 0, 0)
	var purge_id: int = _database.insert_task("Purge", "", DbConstants.TASK_DONE, 0, 0, 0, 1)
	assert_true(_database.set_task_updated_at(purge_id, yesterday))
	assert_true(_database.set_task_updated_at(keep_id, now))
	var deleted: Array = _database.soft_delete_done_tasks_before(today_start)
	assert_eq(deleted.size(), 1)
	assert_eq(deleted[0], purge_id)
	assert_eq(_database.count_tasks(), 1)


func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_task_cleanup_%d" % Time.get_ticks_usec()
	)
	var err := DirAccess.make_dir_recursive_absolute(path)
	assert_eq(err, OK, "temp directory should be created")
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
