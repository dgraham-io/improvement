## GUT tests for tag persistence and assignments.
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


func test_insert_and_fetch_tag() -> void:
	var tag_id: int = _db.insert_tag("Work")
	assert_gt(tag_id, 0)
	var row: Dictionary = _db.fetch_tag_by_name("work")
	assert_eq(int(row.get("id", 0)), tag_id)
	assert_eq(str(row.get("name", "")), "Work")


func test_find_or_create_is_case_insensitive() -> void:
	var first_id: int = _db.insert_tag("Health")
	var row: Dictionary = _db.fetch_tag_by_name("HEALTH")
	assert_eq(int(row.get("id", 0)), first_id)


func test_journal_entry_tags_round_trip() -> void:
	var entry_id: int = _db.insert_journal_entry("Tagged entry")
	var tag_id: int = _db.insert_tag("Side project")
	assert_true(_db.set_journal_entry_tags(entry_id, [tag_id] as Array[int]))
	var tags: Array = _db.fetch_tags_for_journal_entry(entry_id)
	assert_eq(tags.size(), 1)
	assert_eq(str(tags[0].get("name", "")), "Side project")


func test_todo_tags_map() -> void:
	var todo_id: int = _db.insert_todo("Mission", "", DbConstants.TODO_PENDING, 0, 0, 0)
	var tag_id: int = _db.insert_tag("Focus")
	assert_true(_db.set_todo_tags(todo_id, [tag_id] as Array[int]))
	var tags_map: Dictionary = _db.fetch_todo_tags_map()
	assert_true(tags_map.has(todo_id))
	var tags: Array = tags_map[todo_id]
	assert_eq(tags.size(), 1)
	assert_eq(tags[0].name, "Focus")


func test_fetch_journal_entries_filters_by_tag() -> void:
	var tagged_id: int = _db.insert_journal_entry("Tagged")
	_db.insert_journal_entry("Untagged")
	var tag_id: int = _db.insert_tag("FilterMe")
	_db.set_journal_entry_tags(tagged_id, [tag_id] as Array[int])
	var rows: Array = _db.fetch_journal_entries(true, 50, 0, false, [tag_id])
	assert_eq(rows.size(), 1)
	assert_eq(int(rows[0].get("id", 0)), tagged_id)


func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_tags_%d" % Time.get_ticks_usec()
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
