## GUT tests for portable database backup archives.
extends GutTest

const DatabaseScript := preload("res://scripts/autoload/database.gd")
const DatabaseBackup := preload("res://scripts/database/database_backup.gd")
const DatabaseOpen := preload("res://scripts/database/database_open.gd")

var _db: Node
var _test_dir: String = ""
var _db_path: String = ""


func before_each() -> void:
	_test_dir = _make_temp_directory()
	_db = DatabaseScript.new()
	_db._db = null
	_db.is_ready = false
	add_child_autofree(_db)
	assert_true(_db._initialize(_test_dir))
	_db_path = _db.get_db_file_path()
	assert_true(FileAccess.file_exists(_db_path))


func after_each() -> void:
	_db.close_connection()
	await wait_process_frames(2)
	_remove_directory_recursive(_test_dir)


func test_export_and_import_round_trip() -> void:
	_db.insert_journal_entry("backup round trip")
	var archive := _test_dir.path_join(DatabaseBackup.default_archive_filename())
	var export_result: DatabaseBackup.Result = DatabaseBackup.export_to_zip(
		_db_path,
		archive,
		DbConstants.SCHEMA_VERSION
	)
	assert_true(export_result.ok, export_result.error_message)
	assert_true(FileAccess.file_exists(archive))

	var journal_id: int = _db.insert_journal_entry("to be replaced")
	assert_gt(journal_id, 0)

	_db.close_connection()
	var import_result: DatabaseBackup.Result = DatabaseBackup.import_into(archive, _db_path)
	assert_true(import_result.ok, import_result.error_message)

	var verify: DatabaseOpen.OpenResult = DatabaseOpen.try_open_at_directory(_test_dir)
	assert_true(verify.ok, verify.error_message)
	assert_true(
		verify.sqlite.query(
			"SELECT body FROM journal_entries WHERE deleted_at IS NULL;"
		)
	)
	var found_replacement := false
	for row in verify.sqlite.query_result:
		if str(row.get("body", "")) == "to be replaced":
			found_replacement = true
	verify.sqlite.close_db()
	assert_false(found_replacement, "import should replace prior rows")


func test_rejects_invalid_archive() -> void:
	var bad_path := _test_dir.path_join("not-a-db.txt")
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("not sqlite")
	file.close()
	var resolved: DatabaseBackup.Result = DatabaseBackup.resolve_database_bytes(bad_path)
	assert_false(resolved.ok)


func _make_temp_directory() -> String:
	var path := OS.get_cache_dir().path_join(
		"improvement_gut_backup_%d" % Time.get_ticks_usec()
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
