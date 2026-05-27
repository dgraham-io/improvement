## Export/import improvement.db as a portable backup archive (ZIP + manifest).
class_name DatabaseBackup
extends RefCounted

const MANIFEST_VERSION := 1
const MANIFEST_ENTRY := "manifest.json"
const DB_ENTRY := "improvement.db"
const ARCHIVE_EXTENSION := ".improvement-backup.zip"
const SQLITE_HEADER := "SQLite format 3"

const _DatabaseOpen := preload("res://scripts/database/database_open.gd")


class Result:
	var ok: bool = false
	var error_message: String = ""


static func default_archive_filename() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return (
		"improvement-backup-%04d%02d%02d-%02d%02d%02d%s"
		% [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, ARCHIVE_EXTENSION]
	)


static func is_archive_path(path: String) -> bool:
	var lower := path.to_lower()
	return lower.ends_with(".zip") or lower.ends_with(ARCHIVE_EXTENSION)


static func is_plain_db_path(path: String) -> bool:
	return path.to_lower().ends_with(".db")


static func export_to_zip(source_db_path: String, zip_path: String, schema_version: int) -> Result:
	var result := Result.new()
	if source_db_path.is_empty() or not FileAccess.file_exists(source_db_path):
		result.error_message = "Database file was not found:\n%s" % source_db_path
		return result
	if zip_path.is_empty():
		result.error_message = "Choose where to save the backup."
		return result

	var manifest := {
		"manifest_version": MANIFEST_VERSION,
		"app": "Improvement",
		"exported_at": int(Time.get_unix_time_from_system()),
		"schema_version": schema_version,
	}
	var manifest_text := JSON.stringify(manifest, "\t")

	var packer := ZIPPacker.new()
	var err := packer.open(zip_path)
	if err != OK:
		result.error_message = "Could not create backup archive (error %d)." % err
		return result

	err = packer.start_file(MANIFEST_ENTRY)
	if err != OK:
		packer.close()
		result.error_message = "Could not write backup manifest."
		return result
	err = packer.write_file(manifest_text.to_utf8_buffer())
	if err != OK:
		packer.close()
		result.error_message = "Could not write backup manifest."
		return result
	packer.close_file()

	err = packer.start_file(DB_ENTRY)
	if err != OK:
		packer.close()
		result.error_message = "Could not add database to backup."
		return result
	if not _is_sqlite_file(source_db_path):
		packer.close()
		result.error_message = "Database file is empty or invalid."
		return result
	var db_bytes := FileAccess.get_file_as_bytes(source_db_path)
	err = packer.write_file(db_bytes)
	if err != OK:
		packer.close()
		result.error_message = "Could not write database into backup."
		return result
	packer.close_file()
	packer.close()

	result.ok = true
	return result


static func resolve_database_bytes(archive_path: String) -> Result:
	var result := Result.new()
	if archive_path.is_empty():
		result.error_message = "No backup file was selected."
		return result
	if not FileAccess.file_exists(archive_path):
		result.error_message = "Backup file does not exist:\n%s" % archive_path
		return result

	if is_plain_db_path(archive_path):
		if not _is_sqlite_file(archive_path):
			result.error_message = "The selected file is not a valid SQLite database."
			return result
		result.ok = true
		return result

	if not is_archive_path(archive_path):
		result.error_message = "Choose a .improvement-backup.zip file or an improvement.db file."
		return result

	var reader := ZIPReader.new()
	var err := reader.open(archive_path)
	if err != OK:
		result.error_message = "Could not open backup archive (error %d)." % err
		return result

	if not reader.file_exists(DB_ENTRY):
		reader.close()
		result.error_message = "Backup archive is missing improvement.db."
		return result

	if reader.file_exists(MANIFEST_ENTRY):
		var manifest_bytes: PackedByteArray = reader.read_file(MANIFEST_ENTRY)
		var manifest_err := _validate_manifest_text(manifest_bytes.get_string_from_utf8())
		if not manifest_err.is_empty():
			reader.close()
			result.error_message = manifest_err
			return result

	var db_bytes: PackedByteArray = reader.read_file(DB_ENTRY)
	reader.close()
	if db_bytes.is_empty():
		result.error_message = "Backup archive database is empty."
		return result
	if not _bytes_look_like_sqlite(db_bytes):
		result.error_message = "Backup database is not a valid SQLite file."
		return result

	result.ok = true
	return result


static func import_into(archive_path: String, dest_db_path: String) -> Result:
	var result := Result.new()
	if dest_db_path.is_empty():
		result.error_message = "No destination database path."
		return result

	var resolved := resolve_database_bytes(archive_path)
	if not resolved.ok:
		result.error_message = resolved.error_message
		return result

	var staging_path := dest_db_path + ".import-staging"
	var safety_path := _safety_copy_path(dest_db_path)

	if is_plain_db_path(archive_path):
		if not _copy_file(archive_path, staging_path):
			result.error_message = "Could not read the selected database file."
			return result
	else:
		var reader := ZIPReader.new()
		if reader.open(archive_path) != OK:
			result.error_message = "Could not open backup archive."
			return result
		var db_bytes: PackedByteArray = reader.read_file(DB_ENTRY)
		reader.close()
		var staging_file := FileAccess.open(staging_path, FileAccess.WRITE)
		if staging_file == null:
			result.error_message = "Could not prepare database import."
			return result
		staging_file.store_buffer(db_bytes)
		staging_file.close()

	if not _is_sqlite_file(staging_path):
		DirAccess.remove_absolute(staging_path)
		result.error_message = "Imported data is not a valid SQLite database."
		return result

	if FileAccess.file_exists(dest_db_path):
		if not _copy_file(dest_db_path, safety_path):
			DirAccess.remove_absolute(staging_path)
			result.error_message = "Could not back up the current database before import."
			return result

	if not _copy_file(staging_path, dest_db_path):
		DirAccess.remove_absolute(staging_path)
		result.error_message = "Could not replace the live database with the backup."
		return result

	DirAccess.remove_absolute(staging_path)
	_remove_sqlite_sidecars(dest_db_path)
	result.ok = true
	return result


static func checkpoint(sqlite: SQLite) -> bool:
	if sqlite == null:
		return false
	return sqlite.query("PRAGMA wal_checkpoint(FULL);")


static func _validate_manifest_text(text: String) -> String:
	if text.strip_edges().is_empty():
		return ""
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return "Backup manifest is invalid."
	var version := int(parsed.get("manifest_version", 0))
	if version > MANIFEST_VERSION:
		return "This backup was made by a newer version of Improvement."
	return ""


static func _safety_copy_path(dest_db_path: String) -> String:
	var stamp := int(Time.get_unix_time_from_system())
	return "%s.before-import-%d.db" % [dest_db_path.get_basename(), stamp]


static func _copy_file(from_path: String, to_path: String) -> bool:
	if from_path == to_path:
		return true
	var bytes := FileAccess.get_file_as_bytes(from_path)
	var file := FileAccess.open(to_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


static func _is_sqlite_file(path: String) -> bool:
	return _bytes_look_like_sqlite(FileAccess.get_file_as_bytes(path))


static func _bytes_look_like_sqlite(bytes: PackedByteArray) -> bool:
	if bytes.size() < 16:
		return false
	return bytes.slice(0, 16).get_string_from_ascii() == SQLITE_HEADER


static func _remove_sqlite_sidecars(db_path: String) -> void:
	for suffix in ["-wal", "-shm"]:
		var sidecar: String = db_path + suffix
		if FileAccess.file_exists(sidecar):
			DirAccess.remove_absolute(sidecar)
