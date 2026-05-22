## Deletes bootstrap config and default user:// DB files for a fresh setup test.
## Run: godot --path <project> --headless -s res://scripts/tools/reset_app_data.gd
extends SceneTree


func _init() -> void:
	_reset()
	quit(0)


func _reset() -> void:
	AppConfig.clear()
	_remove_db_sidecars(OS.get_user_data_dir())
	var dropbox_dir := AppConfig.suggested_dropbox_directory()
	if not dropbox_dir.is_empty():
		_remove_db_sidecars(dropbox_dir)
	print("Improvement app data reset.")
	print("User data dir: %s" % OS.get_user_data_dir())
	if not dropbox_dir.is_empty():
		print("Also cleared DB in: %s" % dropbox_dir)
	print("Next run will show the database location setup dialog.")


func _remove_db_sidecars(directory: String) -> void:
	var names := PackedStringArray(
		[
			"improvement.db",
			"improvement.db-wal",
			"improvement.db-shm",
			"improvement.db-journal",
		]
	)
	for name in names:
		var path := directory.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
