## Domain model for one journal timeline entry (maps to journal_entries).
class_name JournalEntry
extends Resource

const _DbRow := preload("res://scripts/database/db_row.gd")

@export var id: int = 0
@export var created_at: int = 0
@export var updated_at: int = 0
@export var body: String = ""
@export var deleted_at: int = 0


func is_deleted() -> bool:
	return deleted_at > 0


## First line or truncated body for list previews.
func preview_text(max_chars: int = 240) -> String:
	if body.is_empty():
		return ""
	if body.length() <= max_chars:
		return body
	return body.substr(0, max_chars - 1) + "…"


static func from_row(row: Dictionary) -> JournalEntry:
	var entry := JournalEntry.new()
	entry.id = _DbRow.int_value(row.get("id"))
	entry.created_at = _DbRow.int_value(row.get("created_at"))
	entry.updated_at = _DbRow.int_value(row.get("updated_at"))
	entry.body = _DbRow.string_value(row.get("body"))
	entry.deleted_at = _DbRow.int_value(row.get("deleted_at"))
	return entry
