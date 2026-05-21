## Autoload: journal timeline CRUD and search. Emits signals for UI refresh.
extends Node

signal entry_created(entry: JournalEntry)
signal entry_updated(entry: JournalEntry)
signal entry_deleted(entry_id: int)


const DEFAULT_PAGE_SIZE := 100


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed


func get_sort_newest_first() -> bool:
	return Database.get_setting(DbConstants.SETTING_JOURNAL_SORT_NEWEST_FIRST, "true") == "true"


func set_sort_newest_first(newest_first: bool) -> void:
	Database.set_setting(
		DbConstants.SETTING_JOURNAL_SORT_NEWEST_FIRST,
		"true" if newest_first else "false"
	)


func get_entry_count() -> int:
	return Database.count_journal_entries()


func list_entries(limit: int = DEFAULT_PAGE_SIZE, offset: int = 0) -> Array[JournalEntry]:
	var rows := Database.fetch_journal_entries(get_sort_newest_first(), limit, offset)
	var result: Array[JournalEntry] = []
	for row in rows:
		result.append(JournalEntry.from_row(row))
	return result


func get_entry(entry_id: int) -> JournalEntry:
	var row := Database.fetch_journal_entry_by_id(entry_id)
	if row.is_empty():
		return null
	return JournalEntry.from_row(row)


func create_entry(body: String) -> JournalEntry:
	var id := Database.insert_journal_entry(body)
	if id < 0:
		return null
	var entry := get_entry(id)
	if entry:
		entry_created.emit(entry)
	return entry


func save_entry(entry: JournalEntry) -> bool:
	if entry.id <= 0:
		return false
	if not Database.update_journal_entry(entry):
		return false
	var updated := get_entry(entry.id)
	if updated:
		entry_updated.emit(updated)
	return true


func delete_entry(entry_id: int) -> bool:
	if not Database.soft_delete_journal_entry(entry_id):
		return false
	entry_deleted.emit(entry_id)
	return true


func search(query: String, limit: int = 50) -> Array[JournalEntry]:
	if query.strip_edges().is_empty():
		return list_entries(limit, 0)
	var rows := Database.search_journal_entries(query, limit)
	var result: Array[JournalEntry] = []
	for row in rows:
		result.append(JournalEntry.from_row(row))
	return result
