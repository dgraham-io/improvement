## Reads/writes `user://app_config.json` (DB folder path before SQLite is opened).
class_name AppConfig
extends RefCounted

const CONFIG_USER_PATH := "user://app_config.json"
const CONFIG_VERSION := 1

const KEY_VERSION := "version"
const KEY_DB_DIRECTORY := "db_directory"


static func config_file_path() -> String:
	return ProjectSettings.globalize_path(CONFIG_USER_PATH)


static func is_configured() -> bool:
	return not normalize_directory(read_db_directory()).is_empty()


static func read_db_directory() -> String:
	var data := _read_file()
	return normalize_directory(str(data.get(KEY_DB_DIRECTORY, "")))


static func write_db_directory(db_directory: String) -> bool:
	var normalized := normalize_directory(db_directory)
	if normalized.is_empty():
		push_error("AppConfig: db_directory is empty")
		return false
	return _write_file(
		{KEY_VERSION: CONFIG_VERSION, KEY_DB_DIRECTORY: normalized}
	)


static func db_base_path(db_directory: String) -> String:
	return normalize_directory(db_directory).path_join(DbConstants.DB_FILE_STEM)


static func normalize_directory(path: String) -> String:
	var trimmed := path.strip_edges().replace("\\", "/")
	while trimmed.ends_with("/"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed


static func suggested_dropbox_directory() -> String:
	var home := OS.get_environment("USERPROFILE")
	if home.is_empty():
		home = OS.get_environment("HOME")
	if home.is_empty():
		return ""
	return normalize_directory(home.path_join("Dropbox").path_join("Improvement"))


static func default_local_directory() -> String:
	return normalize_directory(ProjectSettings.globalize_path("user://"))


static func clear() -> void:
	var path := config_file_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _read_file() -> Dictionary:
	var path := config_file_path()
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AppConfig: cannot read %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func _write_file(data: Dictionary) -> bool:
	var path := config_file_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("AppConfig: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
