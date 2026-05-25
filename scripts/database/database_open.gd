## SQLite open helpers (no autoload). Used by Database and GUT tests.
class_name DatabaseOpen
extends RefCounted


class OpenResult:
	var ok: bool = false
	var error_message: String = ""
	var sqlite: SQLite = null


static func format_open_error(directory: String, sqlite_err: String) -> String:
	var db_path := AppConfig.db_base_path(directory) + ".db"
	var err_lower := sqlite_err.to_lower()
	if "locked" in err_lower or "busy" in err_lower:
		return (
			"Could not open improvement.db because it is in use.\n\n"
			+ "Close any other copy of Improvement (this computer or another machine with the same Dropbox folder),\n"
			+ "then try again.\n\n"
			+ "File:\n%s"
		) % db_path
	if "readonly" in err_lower or "read-only" in err_lower:
		return (
			"Could not open improvement.db — the folder is read-only.\n\n"
			+ "Choose a writable folder or fix permissions.\n\n"
			+ "File:\n%s"
		) % db_path
	if not sqlite_err.is_empty():
		return "Could not open improvement.db.\n\n%s\n\nFile:\n%s" % [sqlite_err, db_path]
	return "Could not open improvement.db.\n\nFile:\n%s" % db_path


static func try_open_at_directory(db_directory: String) -> OpenResult:
	var result := OpenResult.new()
	var directory := AppConfig.normalize_directory(db_directory)
	if directory.is_empty():
		result.error_message = "No database folder was selected."
		return result
	if not DirAccess.dir_exists_absolute(directory):
		var err_code := DirAccess.make_dir_recursive_absolute(directory)
		if err_code != OK:
			result.error_message = "Could not create folder:\n%s\n(error %d)" % [directory, err_code]
			return result
	var sqlite := SQLite.new()
	sqlite.path = AppConfig.db_base_path(directory)
	sqlite.foreign_keys = true
	sqlite.default_extension = "db"
	sqlite.verbosity_level = SQLite.QUIET if not OS.is_debug_build() else SQLite.NORMAL
	if not sqlite.open_db():
		var sqlite_err := str(sqlite.error_message)
		result.error_message = format_open_error(directory, sqlite_err)
		return result
	if not sqlite.query("PRAGMA foreign_keys = ON;"):
		var sqlite_err := str(sqlite.error_message)
		result.error_message = "Database opened but failed to initialize (%s)." % sqlite_err
		return result
	result.ok = true
	result.sqlite = sqlite
	return result


## Returns true if an improvement.db file already exists at the given directory.
static func db_file_exists(directory: String) -> bool:
	var path := AppConfig.db_base_path(directory) + ".db"
	return FileAccess.file_exists(path)
